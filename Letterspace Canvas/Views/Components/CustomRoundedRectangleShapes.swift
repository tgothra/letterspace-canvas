import SwiftUI


// Custom shape for top-rounded rectangle
struct CustomTopRoundedRectangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let topLeft = CGPoint(x: rect.minX, y: rect.minY)
        let topRight = CGPoint(x: rect.maxX, y: rect.minY)
        let bottomRight = CGPoint(x: rect.maxX, y: rect.maxY)
        let bottomLeft = CGPoint(x: rect.minX, y: rect.maxY)
        let radius: CGFloat = 8
        
        // Start at top left with rounded corner
        path.move(to: CGPoint(x: topLeft.x + radius, y: topLeft.y))
        
        // Top edge and top right rounded corner
        path.addLine(to: CGPoint(x: topRight.x - radius, y: topRight.y))
        path.addArc(center: CGPoint(x: topRight.x - radius, y: topRight.y + radius),
                    radius: radius,
                    startAngle: Angle(degrees: -90),
                    endAngle: Angle(degrees: 0),
                    clockwise: false)
        
        // Right edge
        path.addLine(to: bottomRight)
        
        // Bottom edge
        path.addLine(to: bottomLeft)
        
        // Left edge
        path.addLine(to: CGPoint(x: topLeft.x, y: topLeft.y + radius))
        
        // Top left rounded corner
        path.addArc(center: CGPoint(x: topLeft.x + radius, y: topLeft.y + radius),
                    radius: radius,
                    startAngle: Angle(degrees: 180),
                    endAngle: Angle(degrees: 270),
                    clockwise: false)
        
        path.closeSubpath()
        return path
    }
}

// Custom shape for bottom-rounded rectangle
struct CustomBottomRoundedRectangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let topLeft = CGPoint(x: rect.minX, y: rect.minY)
        let topRight = CGPoint(x: rect.maxX, y: rect.minY)
        let bottomRight = CGPoint(x: rect.maxX, y: rect.maxY)
        let bottomLeft = CGPoint(x: rect.minX, y: rect.maxY)
        let radius: CGFloat = 8
        
        // Start at top left
        path.move(to: topLeft)
        
        // Top edge
        path.addLine(to: topRight)
        
        // Right edge and bottom right rounded corner
        path.addLine(to: CGPoint(x: bottomRight.x, y: bottomRight.y - radius))
        path.addArc(center: CGPoint(x: bottomRight.x - radius, y: bottomRight.y - radius),
                    radius: radius,
                    startAngle: Angle(degrees: 0),
                    endAngle: Angle(degrees: 90),
                    clockwise: false)
        
        // Bottom edge and bottom left rounded corner
        path.addLine(to: CGPoint(x: bottomLeft.x + radius, y: bottomLeft.y))
        path.addArc(center: CGPoint(x: bottomLeft.x + radius, y: bottomLeft.y - radius),
                    radius: radius,
                    startAngle: Angle(degrees: 90),
                    endAngle: Angle(degrees: 180),
                    clockwise: false)
        
        // Left edge
        path.addLine(to: topLeft)
        
        path.closeSubpath()
        return path
    }
}
