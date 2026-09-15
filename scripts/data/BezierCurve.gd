extends RefCounted
class_name BezierCurve

# Points échantillonnés le long d'une courbe de Bézier cubique — partagé par
# ArrowOverlay et PreviewLinkOverlay (mêmes flèches courbes, styles différents).
static func cubic_points(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, steps: int) -> Array[Vector2]:
	var pts: Array[Vector2] = []
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var u := 1.0 - t
		var pt := u*u*u * p0 \
				+ 3.0*u*u*t * p1 \
				+ 3.0*u*t*t * p2 \
				+ t*t*t     * p3
		pts.append(pt)
	return pts
