import Foundation
import simd

/// Shared 3D collision and layered ground navigation. All positions are foot positions,
/// except lineClear endpoints, which are arbitrary world-space points.
final class WorldNavigation {
    private let surfaces:[WalkSurface]
    private let solids:[SolidVolume]
    private let navigationRadius:Float=0.36
    private let stepHeight:Float=0.4
    private let bodyHeight:Float=1.65
    private let epsilon:Float=0.018
    private struct Cell:Hashable {let x:Int; let z:Int}
    private struct Vertex {let position:SIMD3<Float>}
    private var vertices=[Vertex]()
    private var cells=[Cell:[Int]]()
    private var edgeCache=[Int:[Int]]()
    private var gridReady=false
    private let bucketSize:Float=5
    private var surfaceBuckets=[Cell:[Int]](),solidBuckets=[Cell:[Int]]()

    init(data:WorldData) {
        surfaces=data.surfaces
        solids=data.solids
        for (index,surface) in surfaces.enumerated() {
            for cell in buckets(over:surface.rect) {surfaceBuckets[cell,default:[]].append(index)}
        }
        for (index,solid) in solids.enumerated() {
            for cell in buckets(over:solid.rect) {solidBuckets[cell,default:[]].append(index)}
        }
    }

    /// The highest supporting floor or solid top no more than stepUp above the feet.
    /// A floor far below is returned, so callers can integrate an actual fall.
    func floorHeight(at foot:SIMD3<Float>,stepUp:Float=0.4)->Float? {
        guard finite(foot) else{return nil}
        var result:Float?
        for index in surfaceBuckets[bucket(foot.x,foot.z)] ?? [] {
            let surface=surfaces[index]
            if !surface.rect.contains(foot.x,foot.z) {continue}
            let height=surface.heightAt(foot.x,foot.z)
            if height<=foot.y+max(0,stepUp)+0.002 && (result==nil || height>result!) {result=height}
        }
        // Falling onto a tomb, railing or other finite solid lands on its top,
        // instead of descending through it to the room's base floor.
        for index in solidBuckets[bucket(foot.x,foot.z)] ?? [] {
            let solid=solids[index]
            if solid.rect.contains(foot.x,foot.z) && solid.top<=foot.y+max(0,stepUp)+0.002
                && (result==nil || solid.top>result!) {result=solid.top}
        }
        return result
    }

    /// A vertical body cannot leave the level footprint, intersect finite walls,
    /// pass through an overhead floor slab, or cross a ceiling.
    func clearBody(at foot:SIMD3<Float>,radius:Float=0.32,height:Float=1.65)->Bool {
        guard finite(foot),radius>=0,height>0 else{return false}
        let top=foot.y+height
        for offset in footprint(radius:radius) {
            let x=foot.x+offset.x,z=foot.z+offset.y
            if !(surfaceBuckets[bucket(x,z)] ?? []).contains(where:{surfaces[$0].rect.contains(x,z)}) {return false}
        }
        let area=WalkRect(x:foot.x,z:foot.z,width:radius*2,depth:radius*2)
        for index in nearby(over:area,buckets:solidBuckets) {
            let solid=solids[index]
            if top<=solid.bottom+epsilon || foot.y>=solid.top-epsilon {continue}
            if intersectsCircle(solid.rect,x:foot.x,z:foot.z,radius:radius) {return false}
        }
        let hasCurrentSupport=floorHeight(at:foot,stepUp:0.025).map{abs(foot.y-$0)<0.065} ?? false
        for index in nearby(over:area,buckets:surfaceBuckets) {
            let surface=surfaces[index]
            if !intersectsCircle(surface.rect,x:foot.x,z:foot.z,radius:radius) {continue}
            let rect=surface.rect
            let nearestX=min(rect.x+rect.width/2,max(rect.x-rect.width/2,foot.x))
            let nearestZ=min(rect.z+rect.depth/2,max(rect.z-rect.depth/2,foot.z))
            let centerHeight=surface.heightAt(foot.x,foot.z)
            // A standing cylinder is supported at its center on a slope. The tiny
            // part of its circular footprint inside the uphill slope is intentional.
            let standingOnSurface=rect.contains(foot.x,foot.z) && abs(foot.y-centerHeight)<0.065
            if !standingOnSurface {
                let samples:[SIMD2<Float>]=[SIMD2(nearestX,nearestZ)]+footprint(radius:radius).map {
                    SIMD2(min(rect.x+rect.width/2,max(rect.x-rect.width/2,foot.x+$0.x)),
                          min(rect.z+rect.depth/2,max(rect.z-rect.depth/2,foot.z+$0.y)))
                }
                for sample in samples {
                    let dx=sample.x-foot.x,dz=sample.y-foot.z
                    if dx*dx+dz*dz>radius*radius+0.001 {continue}
                    let floor=surface.heightAt(sample.x,sample.y)
                    // Permit the front edge of a supported body to reach a small
                    // adjoining step before its center crosses onto that surface.
                    if hasCurrentSupport && !rect.contains(foot.x,foot.z) && floor<=foot.y+stepHeight+epsilon {continue}
                    if foot.y<floor-epsilon && top>floor-surface.thickness+epsilon {return false}
                }
            }
            // Ceiling thickness is small but finite, allowing a separately modelled
            // higher storey to exist above a lower room's ceiling.
            if foot.y<surface.ceiling+0.25-epsilon && top>surface.ceiling+epsilon {return false}
        }
        return true
    }

    /// Horizontal movement with wall sliding and small substeps. Feet follow
    /// connected slopes and small steps; descending a ledge preserves elevation
    /// until the caller's gravity lands the body on the lower floor.
    func moveGround(from foot:SIMD3<Float>,by delta:SIMD3<Float>,radius:Float=0.32)->SIMD3<Float> {
        guard finite(foot),finite(delta) else{return foot}
        let length=hypot(delta.x,delta.z)
        guard length>0 else{return foot}
        let count=max(1,Int(ceil(length/0.13)))
        let step=SIMD3(delta.x/Float(count),0,delta.z/Float(count))
        var result=foot
        for _ in 0..<count {
            let diagonal=result+step
            if let next=groundCandidate(from:result,to:diagonal,radius:radius) {result=next;continue}
            if abs(step.x)>0,let next=groundCandidate(from:result,to:result+SIMD3(step.x,0,0),radius:radius) {result=next}
            if abs(step.z)>0,let next=groundCandidate(from:result,to:result+SIMD3(0,0,step.z),radius:radius) {result=next}
        }
        return result
    }

    /// Exact segment clipping against finite wall boxes, sloping floor slabs,
    /// and ceiling slabs. The world boundary also blocks fire and line of sight.
    func lineClear(from a:SIMD3<Float>,to b:SIMD3<Float>)->Bool {
        guard finite(a),finite(b) else{return false}
        let delta=b-a
        let length=simd_length(delta)
        let sampleCount=max(1,Int(ceil(length/0.16)))
        for i in 0...sampleCount {
            let point=a+delta*(Float(i)/Float(sampleCount))
            if !(surfaceBuckets[bucket(point.x,point.z)] ?? []).contains(where:{surfaces[$0].rect.contains(point.x,point.z)}) {return false}
        }
        let area=WalkRect(x:(a.x+b.x)/2,z:(a.z+b.z)/2,width:abs(delta.x),depth:abs(delta.z))
        for index in nearby(over:area,buckets:solidBuckets) {
            let solid=solids[index]
            if segmentIntersects(a,delta:delta,rect:solid.rect,
                                 relativeY:a.y,relativeDY:delta.y,
                                 bottom:solid.bottom+0.002,top:solid.top-0.002) {return false}
        }
        for index in nearby(over:area,buckets:surfaceBuckets) {
            let surface=surfaces[index]
            let relativeY=a.y-surface.heightAt(a.x,a.z)
            let relativeDY=delta.y-delta.x*surface.slopeX-delta.z*surface.slopeZ
            if surface.thickness>0.004 && segmentIntersects(a,delta:delta,rect:surface.rect,
                                 relativeY:relativeY,relativeDY:relativeDY,
                                 bottom:-surface.thickness+0.002,top:-0.002) {return false}
            if segmentIntersects(a,delta:delta,rect:surface.rect,
                                 relativeY:a.y,relativeDY:delta.y,
                                 bottom:surface.ceiling+0.002,top:surface.ceiling+0.248) {return false}
        }
        return true
    }

    /// Ground waypoints retain elevation at every layer. Edges are accepted only
    /// after sampling continuous support and headroom, so overlapping floors never
    /// produce a vertical teleport or a shortcut through a staircase slab.
    func route(from origin:SIMD3<Float>,to destination:SIMD3<Float>)->[SIMD3<Float>] {
        guard let start=projectedFoot(origin),let finish=projectedFoot(destination),
              clearBody(at:start,radius:navigationRadius),clearBody(at:finish,radius:navigationRadius) else{return []}
        if hypot(finish.x-start.x,finish.z-start.z)<0.12 && abs(finish.y-start.y)<0.12 {return [finish]}
        if groundEdge(from:start,to:finish) {return [finish]}
        prepareGrid()
        guard let first=nearestVertex(to:start),let last=nearestVertex(to:finish) else{return []}
        if first==last {return [vertices[first].position,finish]}
        var heap=MinHeap(),costs=[Int:Float](),parents=[Int:Int](),closed=Set<Int>()
        costs[first]=0;heap.push(first,score:heuristic(vertices[first].position,finish))
        while let current=heap.pop() {
            if closed.contains(current) {continue}
            if current==last {
                var indices=[current],cursor=current
                while cursor != first {
                    guard let previous=parents[cursor] else{return []}
                    indices.append(previous);cursor=previous
                }
                var path=indices.reversed().map{vertices[$0].position}
                path.append(finish)
                return simplify(path,from:start)
            }
            closed.insert(current)
            let base=costs[current] ?? .greatestFiniteMagnitude
            for neighbor in neighbors(of:current) where !closed.contains(neighbor) {
                let cost=base+heuristic(vertices[current].position,vertices[neighbor].position)
                if cost<(costs[neighbor] ?? .greatestFiniteMagnitude) {
                    costs[neighbor]=cost;parents[neighbor]=current
                    heap.push(neighbor,score:cost+heuristic(vertices[neighbor].position,finish))
                }
            }
        }
        return []
    }

    private func groundCandidate(from current:SIMD3<Float>,to candidate:SIMD3<Float>,radius:Float)->SIMD3<Float>? {
        var next=candidate
        let priorFloor=floorHeight(at:current,stepUp:0.07)
        let grounded=priorFloor.map{abs(current.y-$0)<0.09} ?? false
        if grounded {
            guard let floor=floorHeight(at:next,stepUp:stepHeight) else{return nil}
            if floor>=current.y-stepHeight && floor<=current.y+stepHeight+0.002 {next.y=floor}
        }
        return clearBody(at:next,radius:radius,height:bodyHeight) ? next:nil
    }

    private func projectedFoot(_ point:SIMD3<Float>)->SIMD3<Float>? {
        guard let height=floorHeight(at:point,stepUp:stepHeight) else{return nil}
        return SIMD3(point.x,height,point.z)
    }

    private func groundEdge(from a:SIMD3<Float>,to b:SIMD3<Float>)->Bool {
        let horizontal=hypot(b.x-a.x,b.z-a.z)
        // Vertical travel needs horizontal support; this is the key layered-grid invariant.
        if horizontal<0.001 {return abs(a.y-b.y)<0.04}
        if abs(a.y-b.y)>horizontal*0.70+0.04 {return false}
        let count=max(1,Int(ceil(horizontal/0.20)))
        var previous=a
        for i in 1...count {
            let amount=Float(i)/Float(count)
            let sample=SIMD3(a.x+(b.x-a.x)*amount,previous.y,a.z+(b.z-a.z)*amount)
            guard let floor=floorHeight(at:sample,stepUp:stepHeight) else{return false}
            if abs(floor-previous.y)>stepHeight+0.002 {return false}
            let next=SIMD3(sample.x,floor,sample.z)
            if !clearBody(at:next,radius:navigationRadius,height:bodyHeight) {return false}
            previous=next
        }
        return abs(previous.y-b.y)<0.08
    }

    private func prepareGrid() {
        guard !gridReady else{return};gridReady=true
        for surface in surfaces {
            let minX=Int(ceil(surface.rect.x-surface.rect.width/2)),maxX=Int(floor(surface.rect.x+surface.rect.width/2))
            let minZ=Int(ceil(surface.rect.z-surface.rect.depth/2)),maxZ=Int(floor(surface.rect.z+surface.rect.depth/2))
            guard minX<=maxX,minZ<=maxZ else{continue}
            for x in minX...maxX {for z in minZ...maxZ {
                let point=SIMD3(Float(x),surface.heightAt(Float(x),Float(z)),Float(z))
                guard clearBody(at:point,radius:navigationRadius,height:bodyHeight) else{continue}
                let cell=Cell(x:x,z:z)
                if (cells[cell] ?? []).contains(where:{abs(vertices[$0].position.y-point.y)<0.025}) {continue}
                cells[cell,default:[]].append(vertices.count);vertices.append(Vertex(position:point))
            }}
        }
    }

    private func neighbors(of index:Int)->[Int] {
        if let cached=edgeCache[index] {return cached}
        let point=vertices[index].position,cell=Cell(x:Int(point.x.rounded()),z:Int(point.z.rounded()))
        var result=[Int]()
        for dx in -1...1 {for dz in -1...1 where dx != 0 || dz != 0 {
            for candidate in cells[Cell(x:cell.x+dx,z:cell.z+dz)] ?? [] {
                let target=vertices[candidate].position
                if abs(target.y-point.y)<=0.65 && groundEdge(from:point,to:target) {result.append(candidate)}
            }
        }}
        edgeCache[index]=result;return result
    }

    private func nearestVertex(to point:SIMD3<Float>)->Int? {
        let center=Cell(x:Int(point.x.rounded()),z:Int(point.z.rounded()))
        var candidates=[Int]()
        for dx in -3...3 {for dz in -3...3 {candidates += cells[Cell(x:center.x+dx,z:center.z+dz)] ?? []}}
        candidates.sort{heuristic(vertices[$0].position,point)<heuristic(vertices[$1].position,point)}
        return candidates.first{groundEdge(from:point,to:vertices[$0].position)}
    }

    private func simplify(_ path:[SIMD3<Float>],from start:SIMD3<Float>)->[SIMD3<Float>] {
        var result=[SIMD3<Float>](),anchor=start,index=0
        while index<path.count {
            var farthest=index
            // Retain corners and slope changes unless the whole shortcut is truly walkable.
            for next in stride(from:min(path.count-1,index+16),through:index,by:-1) {
                if groundEdge(from:anchor,to:path[next]) {farthest=next;break}
            }
            let waypoint=path[farthest]
            if simd_distance(anchor,waypoint)>0.025 {result.append(waypoint)}
            anchor=waypoint;index=farthest+1
        }
        return result
    }

    private func footprint(radius:Float)->[SIMD2<Float>] {
        let diagonal=radius*0.70710678
        return [SIMD2(0,0),SIMD2(radius,0),SIMD2(-radius,0),SIMD2(0,radius),SIMD2(0,-radius),
                SIMD2(diagonal,diagonal),SIMD2(-diagonal,diagonal),SIMD2(diagonal,-diagonal),SIMD2(-diagonal,-diagonal)]
    }
    private func bucket(_ x:Float,_ z:Float)->Cell {Cell(x:Int(floor(x/bucketSize)),z:Int(floor(z/bucketSize)))}
    private func buckets(over rect:WalkRect)->[Cell] {
        let first=bucket(rect.x-rect.width/2,rect.z-rect.depth/2),last=bucket(rect.x+rect.width/2,rect.z+rect.depth/2)
        var result=[Cell]()
        for x in first.x...last.x {for z in first.z...last.z {result.append(Cell(x:x,z:z))}}
        return result
    }
    private func nearby(over rect:WalkRect,buckets table:[Cell:[Int]])->[Int] {
        let covering=buckets(over:rect)
        if covering.count==1 {return table[covering[0]] ?? []}
        var result=[Int](),seen=Set<Int>()
        for cell in covering {for index in table[cell] ?? [] where seen.insert(index).inserted {result.append(index)}}
        return result
    }
    private func intersectsCircle(_ rect:WalkRect,x:Float,z:Float,radius:Float)->Bool {
        let dx=max(0,abs(x-rect.x)-rect.width/2),dz=max(0,abs(z-rect.z)-rect.depth/2)
        return dx*dx+dz*dz<radius*radius+0.00001
    }
    private func finite(_ point:SIMD3<Float>)->Bool {point.x.isFinite && point.y.isFinite && point.z.isFinite}
    private func heuristic(_ a:SIMD3<Float>,_ b:SIMD3<Float>)->Float {hypot(a.x-b.x,a.z-b.z)+abs(a.y-b.y)*1.1}
    private func segmentIntersects(_ a:SIMD3<Float>,delta:SIMD3<Float>,rect:WalkRect,
                                   relativeY:Float,relativeDY:Float,bottom:Float,top:Float)->Bool {
        guard top>bottom else{return false}
        var low:Float=0,high:Float=1
        func clip(_ origin:Float,_ direction:Float,_ minimum:Float,_ maximum:Float)->Bool {
            if abs(direction)<0.000001 {return origin>=minimum && origin<=maximum}
            let first=(minimum-origin)/direction,second=(maximum-origin)/direction
            low=max(low,min(first,second));high=min(high,max(first,second));return low<=high
        }
        return clip(a.x,delta.x,rect.x-rect.width/2,rect.x+rect.width/2)
            && clip(a.z,delta.z,rect.z-rect.depth/2,rect.z+rect.depth/2)
            && clip(relativeY,relativeDY,bottom,top) && low<=high
    }

    private struct MinHeap {
        private var items=[(index:Int,score:Float)]()
        mutating func push(_ index:Int,score:Float) {
            items.append((index,score));var child=items.count-1
            while child>0 {
                let parent=(child-1)/2
                if items[parent].score<=items[child].score {break}
                items.swapAt(parent,child);child=parent
            }
        }
        mutating func pop()->Int? {
            guard !items.isEmpty else{return nil}
            let first=items[0].index,last=items.removeLast()
            if !items.isEmpty {
                items[0]=last;var parent=0
                while true {
                    let left=parent*2+1,right=left+1
                    if left>=items.count {break}
                    let child=right<items.count && items[right].score<items[left].score ? right:left
                    if items[parent].score<=items[child].score {break}
                    items.swapAt(parent,child);parent=child
                }
            }
            return first
        }
    }
}
