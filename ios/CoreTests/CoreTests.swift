import XCTest
@testable import NaviGatARCore

private func assertClose(_ a: Vec3, _ b: Vec3, _ tolerance: Float = 1e-3, file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertLessThan(Geo.distance(a, b), tolerance, "\(a) != \(b)", file: file, line: line)
}

final class GeometryTests: XCTestCase {
    func testPoseInverseAndComposition() {
        let a = Pose(position: Vec3(1, 2, 3), yaw: 0.7)
        let b = Pose(position: Vec3(-4, 0, 2), yaw: -2.1)
        let p = Vec3(0.3, -1, 5)
        assertClose(a.inverse().apply(a.apply(p)), p)
        assertClose((a * b).apply(p), a.apply(b.apply(p)))
        let identity = a * a.inverse()
        assertClose(identity.position, .zero)
        XCTAssertEqual(identity.yaw, 0, accuracy: 1e-5)
    }

    func testFacingPointsZAxis() {
        let pose = Pose.facing(Vec3(1, 0, 0), at: .zero)
        assertClose(pose.zAxis, Vec3(1, 0, 0))
    }

    func testTurnSign() {
        // Walking toward -Z then toward +X is a right turn for a person with +Y up.
        XCTAssertEqual(Geo.signedTurnDegrees(from: Vec3(0, 0, -1), to: Vec3(1, 0, 0)), 90, accuracy: 0.01)
        XCTAssertEqual(Geo.signedTurnDegrees(from: Vec3(0, 0, -1), to: Vec3(-1, 0, 0)), -90, accuracy: 0.01)
    }

    func testAverageYawWrapsAround() {
        let avg = Pose.average([Pose(position: .zero, yaw: .pi - 0.05), Pose(position: .zero, yaw: -.pi + 0.05)])!
        XCTAssertEqual(abs(avg.yaw), .pi, accuracy: 0.01)
    }
}

final class AnchorTests: XCTestCase {
    func testWallCodeUsesWallNormal() {
        // Code on a wall facing +X, camera standing at +X looking slightly sideways.
        let corners: [Vec3?] = [Vec3(0, 1.6, -0.1), Vec3(0, 1.6, 0.1), Vec3(0, 1.4, -0.1), Vec3(0, 1.4, 0.1)]
        let estimate = QRAnchorEstimator.estimate(cornerHits: corners, centerHit: nil, centerNormal: nil,
                                                  cameraPosition: Vec3(1, 1.4, 0.3),
                                                  cameraForward: Geo.normalize(Vec3(-1, 0, -0.4)))
        XCTAssertEqual(estimate.quality, .precise)
        assertClose(estimate.pose.position, Vec3(0, 1.5, 0))
        assertClose(estimate.pose.zAxis, Vec3(1, 0, 0))
    }

    func testFallbackWhenNothingHit() {
        let estimate = QRAnchorEstimator.estimate(cornerHits: [nil, nil, nil, nil], centerHit: nil, centerNormal: nil,
                                                  cameraPosition: Vec3(0, 1.4, 0), cameraForward: Vec3(0, 0, -1))
        XCTAssertEqual(estimate.quality, .approximate)
        assertClose(estimate.pose.position, Vec3(0, 1.4, -0.6))
        assertClose(estimate.pose.zAxis, Vec3(0, 0, 1))
    }

    func testAccumulatorNeedsConsistentSamples() {
        var acc = AnchorSampleAccumulator()
        let e = QRAnchorEstimator.Estimate(pose: Pose(position: Vec3(1, 1, 1), yaw: 0.2), quality: .precise)
        XCTAssertNil(acc.add(payload: "a", estimate: e, time: 0))
        XCTAssertNil(acc.add(payload: "a", estimate: e, time: 0.3))
        let result = acc.add(payload: "a", estimate: e, time: 0.6)
        XCTAssertNotNil(result)
        assertClose(result!.pose.position, Vec3(1, 1, 1))
        // Outlier is rejected.
        var acc2 = AnchorSampleAccumulator()
        _ = acc2.add(payload: "a", estimate: e, time: 0)
        _ = acc2.add(payload: "a", estimate: e, time: 0.1)
        let far = QRAnchorEstimator.Estimate(pose: Pose(position: Vec3(3, 1, 1), yaw: 0.2), quality: .precise)
        XCTAssertNil(acc2.add(payload: "a", estimate: far, time: 0.2))
    }
}

final class RoutingTests: XCTestCase {
    // A "true" building: signs A, B, C placed in a ground-truth frame.
    let signA = Pose(position: Vec3(0, 1.5, 0), yaw: 0)            // faces +Z
    let signB = Pose(position: Vec3(6, 1.5, -10), yaw: -.pi / 2)   // faces -X
    let signC = Pose(position: Vec3(14, 1.5, -10), yaw: .pi)       // faces -Z

    let idA = UUID(), idB = UUID(), idC = UUID(), idD = UUID()

    /// Records a route in an AR session whose world frame differs from ground truth by `session`.
    func record(from: Pose, to: Pose, truePath: [Vec3], session: Pose, fromID: UUID, toID: UUID) -> Segment {
        var recorder = RouteRecorder(startAnchor: session * from)
        for p in truePath { recorder.add(cameraPosition: session.apply(p)) }
        recorder.addNote("Open the door!", cameraPosition: session.apply(truePath[truePath.count / 2]))
        return recorder.makeSegment(from: fromID, to: toID, endAnchor: session * to, finalCameraPosition: nil,
                                    stepFree: true, bidirectional: true)
    }

    func line(_ a: Vec3, _ b: Vec3, step: Float = 0.3) -> [Vec3] {
        let n = Int(Geo.distance(a, b) / step)
        return (0...n).map { a + (b - a) * (Float($0) / Float(n)) }
    }

    func makeBuilding() -> (Building, [Vec3], [Vec3]) {
        let pathAB = line(Vec3(0, 1.3, 0.7), Vec3(0, 1.3, -10)) + line(Vec3(0.3, 1.3, -10), Vec3(5.3, 1.3, -10))
        let pathBC = line(Vec3(6.6, 1.3, -10), Vec3(14, 1.3, -10.6))
        let ab = record(from: signA, to: signB, truePath: pathAB,
                        session: Pose(position: Vec3(3, -1, 2), yaw: 1.1), fromID: idA, toID: idB)
        let bc = record(from: signB, to: signC, truePath: pathBC,
                        session: Pose(position: Vec3(-7, 0.2, 5), yaw: -2.5), fromID: idB, toID: idC)
        let link = Segment(fromID: idC, toID: idD, kind: .connector, connectorKind: .elevator, stepFree: true)
        let building = Building(name: "Test",
                                locations: [Location(id: idA, name: "A"), Location(id: idB, name: "B"),
                                            Location(id: idC, name: "C"), Location(id: idD, name: "D", floor: "2")],
                                segments: [ab, bc, link])
        return (building, pathAB, pathBC)
    }

    func testRoutesChainAcrossSegmentsInANewSession() throws {
        let (building, pathAB, pathBC) = makeBuilding()
        let route = try XCTUnwrap(RoutePlanner.plan(in: building, from: idA, to: idC, stepFreeOnly: false))
        XCTAssertEqual(route.legs.count, 1)
        XCTAssertEqual(route.locationPath, [idA, idB, idC])

        // The visitor's AR session has yet another world frame; they scan sign A.
        let visitor = Pose(position: Vec3(20, 0, -3), yaw: 2.2)
        let alignment = visitor * signA
        let leg = route.legs[0]
        let world = leg.points.map(alignment.apply)
        let expected = (pathAB + pathBC).map(visitor.apply)
        XCTAssertEqual(world.count, expected.count)
        for (w, e) in zip(world, expected) { assertClose(w, e, 1e-3) }

        // Sign C's predicted pose matches reality, so re-aligning there is consistent.
        let predictedC = alignment * leg.nodePoses[idC]!
        assertClose(predictedC.position, (visitor * signC).position)
    }

    func testReverseTraversal() throws {
        let (building, pathAB, _) = makeBuilding()
        let route = try XCTUnwrap(RoutePlanner.plan(in: building, from: idB, to: idA, stepFreeOnly: false))
        let alignment = signB // visitor world == ground truth
        let world = route.legs[0].points.map(alignment.apply)
        for (w, e) in zip(world, pathAB.reversed()) { assertClose(w, e) }
        assertClose((alignment * route.legs[0].nodePoses[idA]!).position, signA.position)
        XCTAssertEqual(route.legs[0].notes.count, 1)
    }

    func testConnectorStartsNewLeg() throws {
        let (building, _, _) = makeBuilding()
        let route = try XCTUnwrap(RoutePlanner.plan(in: building, from: idA, to: idD, stepFreeOnly: true))
        XCTAssertEqual(route.legs.count, 2)
        XCTAssertEqual(route.legs[0].exitConnector?.kind, .elevator)
        XCTAssertEqual(route.legs[1].startID, idD)
        XCTAssertTrue(route.legs[1].points.isEmpty)
        XCTAssertEqual(route.legIndex(containing: idD), 1)
        XCTAssertEqual(RoutePlanner.connectorText(route.legs[0].exitConnector!, in: building), "Take the elevator to floor 2")
    }

    func testStepFreeFilterAndUnreachable() {
        var (building, _, _) = makeBuilding()
        building.segments[2].stepFree = false
        XCTAssertNil(RoutePlanner.plan(in: building, from: idA, to: idD, stepFreeOnly: true))
        XCTAssertNotNil(RoutePlanner.plan(in: building, from: idA, to: idD, stepFreeOnly: false))
        building.segments.removeLast()
        XCTAssertEqual(building.unreachableLocations().map(\.name), ["D"])
    }
}

final class DirectionsTests: XCTestCase {
    func testLShapedRouteTurnsRight() {
        let route = DemoRoute.building()
        let plan = RoutePlanner.plan(in: route, from: DemoRoute.startID, to: DemoRoute.destinationID, stepFreeOnly: false)!
        let leg = plan.legs[0]
        let steps = DirectionsBuilder.steps(points: leg.points, notes: leg.notes, finalText: "Arrive", finalIsConnector: false)
        XCTAssertEqual(steps.map(\.kind), [.start, .note, .right, .arrive])
        XCTAssertEqual(steps[2].arc, 4.0, accuracy: 0.3)
        XCTAssertEqual(steps.last!.arc, leg.length, accuracy: 0.01)
    }

    func testTrackerProgressAndArrival() {
        let points = (0...20).map { Vec3(0, 0, -Float($0) * 0.5) }
        let steps = DirectionsBuilder.steps(points: points, notes: [], finalText: "Arrive", finalIsConnector: false)
        var tracker = LegTracker(points: points, steps: steps)
        var status = tracker.update(position: Vec3(0.4, 1.3, -3))
        XCTAssertEqual(status.arc, 3, accuracy: 0.01)
        XCTAssertFalse(status.offRoute)
        XCTAssertFalse(status.reachedEnd)
        XCTAssertEqual(status.distanceToNextStep, 7, accuracy: 0.01)
        status = tracker.update(position: Vec3(4, 1.3, -5))
        XCTAssertTrue(status.offRoute)
        status = tracker.update(position: Vec3(0, 1.3, -9.5))
        XCTAssertTrue(status.reachedEnd)
    }

    func testResampleAndSimplify() {
        let index = PolylineIndex(points: [Vec3(0, 0, 0), Vec3(0, 0, -2), Vec3(2, 0, -2)])
        XCTAssertEqual(index.total, 4, accuracy: 1e-4)
        XCTAssertEqual(index.resample(spacing: 0.5).count, 9)
        XCTAssertEqual(index.simplifiedIndices(tolerance: 0.1), [0, 1, 2])
        assertClose(index.point(atArc: 3), Vec3(1, 0, -2))
    }

    func testDistanceText() {
        XCTAssertEqual(DistanceText.string(12.4, imperial: false), "12 m")
        XCTAssertEqual(DistanceText.string(1500, imperial: false), "1.5 km")
        XCTAssertEqual(DistanceText.string(10, imperial: true), "35 ft")
        XCTAssertEqual(DistanceText.spoken(1, imperial: false), "1 meter")
    }
}

final class SharingTests: XCTestCase {
    func testPayloadRoundTrip() {
        let payload = QRPayload(buildingID: UUID(), locationID: UUID())
        XCTAssertEqual(QRPayload(string: payload.string), payload)
        XCTAssertNil(QRPayload(string: "https://example.com"))
        XCTAssertNil(QRPayload(string: "navigatar://location?b=x"))
    }

    func testBuildingFileRoundTrip() throws {
        let building = DemoRoute.building()
        let data = try BuildingFile.encode(building)
        let decoded = try BuildingFile.decode(data)
        XCTAssertEqual(decoded.id, building.id)
        XCTAssertEqual(decoded.segments.first?.points.count, building.segments.first?.points.count)
        XCTAssertEqual(decoded.segments.first?.endPose, building.segments.first?.endPose)
        XCTAssertThrowsError(try BuildingFile.decode(Data("{}".utf8)))
        XCTAssertEqual(BuildingFile.suggestedFileName(for: Building(name: "Hall #1 / East")), "Hall 1  East.navigatar.json")
    }
}
