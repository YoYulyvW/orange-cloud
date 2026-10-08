//
//  TrafficBubbleMap.swift
//  Orange Cloud
//
//  iOS 16.4 移植：SwiftUI Map 新 API（MapContentBuilder）仅 iOS 17+，
//  这里用 MKMapView + UIViewRepresentable 实现等价的流量气泡地图。
//

import SwiftUI
import MapKit

/// 地图上的一个流量气泡
struct TrafficBubblePoint: Identifiable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let diameter: CGFloat
    let isHighThreat: Bool
    let label: String
    let valueText: String
}

/// MKMapView 封装：展示一组气泡点（圆点大小映射请求量，威胁高亮红）。
struct TrafficBubbleMap: UIViewRepresentable {

    let points: [TrafficBubblePoint]
    let initialRegion: MKCoordinateRegion

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.setRegion(initialRegion, animated: false)
        map.isRotateEnabled = false
        map.isPitchEnabled = false
        map.pointOfInterestFilter = .excludingAll
        map.showsCompass = false
        map.showsScale = false
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        let existing = map.annotations.filter { !($0 is MKUserLocation) }
        map.removeAnnotations(existing)
        map.addAnnotations(points.map { TrafficAnnotation($0) })
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let ann = annotation as? TrafficAnnotation else { return nil }
            let reuseID = "trafficBubble"
            let view = (mapView.dequeueReusableAnnotationView(withIdentifier: reuseID) as? TrafficAnnotationView)
                ?? TrafficAnnotationView(annotation: ann, reuseIdentifier: reuseID)
            view.annotation = ann
            view.apply(ann)
            return view
        }
    }
}

/// 携带气泡数据的注解
final class TrafficAnnotation: NSObject, MKAnnotation {
    let point: TrafficBubblePoint
    var coordinate: CLLocationCoordinate2D { point.coordinate }
    var title: String? { point.label }
    init(_ point: TrafficBubblePoint) {
        self.point = point
    }
}

/// 气泡视图：用 CAShapeLayer 画圆，尺寸/颜色随数据更新。
final class TrafficAnnotationView: MKAnnotationView {

    private let circle = CAShapeLayer()

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        frame = CGRect(x: 0, y: 0, width: 44, height: 44)
        backgroundColor = .clear
        layer.addSublayer(circle)
        isEnabled = false
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func apply(_ ann: TrafficAnnotation) {
        let d = ann.point.diameter
        bounds = CGRect(x: 0, y: 0, width: d, height: d)
        circle.frame = bounds
        let color = ann.point.isHighThreat ? UIColor.systemRed : UIColor.ocOrange
        circle.path = UIBezierPath(ovalIn: bounds).cgPath
        circle.fillColor = color.withAlphaComponent(0.55).cgColor
        circle.strokeColor = color.cgColor
        circle.lineWidth = 1.5
        centerOffset = .zero
    }
}

extension UIColor {
    /// 品牌橙（Cloudflare #F48120）
    static var ocOrange: UIColor { UIColor(red: 244/255, green: 129/255, blue: 32/255, alpha: 1) }
}
