//
//  Shaders.metal
//  chapter05
//
//  Created by Marius on 2/3/16.
//  Copyright © 2016 Marius Horga. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

#define M_PI 3.14159265358979323846264338327950288

struct Vertex {
  float2 position;
};

struct VertexOut{
  float4 position [[position]];
  float2 texCoord;
  float shadowAlpha;
};

struct VertUniform {
  float2 touchPosition;
  float2 shift;
  float transpose;
  float flip;
  float foldAlpha;
};

enum TweenType:int {
  linear = 0,
  bezier,
  quadratic,
  cubic,
  quartic,
  quintic,
  sine,
  circular,
  exponential,
  elastic,
  back,
  bounce
};
  
enum EaseType:int { easein = 0, easeout, easeinout };
    
struct Curve {
  TweenType type;
  EaseType ease;
  
  float ax;
  float bx;
  float cx;
  
  float ay;
  float by;
  float cy;
  
  Curve(float p1x, float p1y, float p2x, float p2y) {
    // Calculate the polynomial coefficients, implicit first and last control points are (0,0) and (1,1).
    cx = 3.0 * p1x;
    bx = 3.0 * (p2x - p1x) - cx;
    ax = 1.0 - cx -bx;
    
    cy = 3.0 * p1y;
    by = 3.0 * (p2y - p1y) - cy;
    ay = 1.0 - cy - by;
    type = bezier;
    ease = easeout;
  }
  Curve(TweenType type, EaseType ease):type(type),ease(ease){}
  float sampleCurveX(float t)
  {
    // `ax t^3 + bx t^2 + cx t' expanded using Horner's rule.
    return ((ax * t + bx) * t + cx) * t;
  }
  
  float sampleCurveY(float t)
  {
    return ((ay * t + by) * t + cy) * t;
  }
  
  float sampleCurveDerivativeX(float t)
  {
    return (3.0 * ax * t + 2.0 * bx) * t + cx;
  }
  
  // Given an x value, find a parametric value it came from.
  float solveCurveX(float x, float epsilon)
  {
    float t0;
    float t1;
    float t2;
    float x2;
    float d2;
    int i;
    
    // First try a few iterations of Newton's method -- normally very fast.
    for (t2 = x, i = 0; i < 8; i++) {
      x2 = sampleCurveX(t2) - x;
      if (fabs (x2) < epsilon)
        return t2;
      d2 = sampleCurveDerivativeX(t2);
      if (fabs(d2) < 1e-6)
        break;
      t2 = t2 - x2 / d2;
    }
    
    // Fall back to the bisection method for reliability.
    t0 = 0.0;
    t1 = 1.0;
    t2 = x;
    
    if (t2 < t0)
      return t0;
    if (t2 > t1)
      return t1;
    
    while (t0 < t1) {
      x2 = sampleCurveX(t2);
      if (fabs(x2 - x) < epsilon)
        return t2;
      if (x > x2)
        t0 = t2;
      else
        t1 = t2;
      t2 = (t1 - t0) * .5 + t0;
    }
    
    // Failure.
    return t2;
  }
  
  float solve(float x, float epsilon)
  {
    return sampleCurveY(solveCurveX(x, epsilon));
  }
  float easeIn(float t){
    switch (type) {
      case bezier:
        return sampleCurveY(solveCurveX(t, 1.0/1000));
      case linear:
        return t;
      case quadratic:
        return t*t;
      case cubic:
        return t*t*t;
      case quartic:
        return t*t*t*t;
      case quintic:
        return t*t*t*t*t;
      case sine:
        return sin((t - 1) * M_PI / 2) + 1;
      case circular:
        return 1 - sqrt(1 - (t * t));
      case exponential:
        return (t == 0.0) ? t : pow(2, 10 * (t - 1));
      case elastic:
        return sin(13 * M_PI / 2 * t) * pow(2, 10 * (t - 1));
      case back:
        return t*t*t - t*sin(t * M_PI);
      case bounce:
        t = 1 - t;
        if (t < 1/2.75) {
          return 1 - (7.5625*t*t);
        } else if (t < (2/2.75)) {
          t -= 1.5/2.75;
          return 1 - (7.5625*t*t + .75);
        } else if (t < (2.5/2.75)) {
          t -= 2.25/2.75;
          return 1 - (7.5625*t*t + .9375);
        } else {
          t -= 2.625/2.75;
          return 1 - (7.5625*t*t + .984375);
        }
    }
  }
  float easeOut(float t){
    return 1 - easeIn(1 - t);
  }
  float solve(float t){
    switch (ease) {
      case easein:
        return easeIn(t);
      case easeout:
        return easeOut(t);
      case easeinout:
        float side = clamp(sign(t - 0.5), 0.0, 1.0);
        return (mix(easeIn(t*2), easeOut(t*2-1), side) + side) * 0.5;
    }
  }
};


float2 apply(float2 a, float transposed, float flip){
  a = mix(a, float2(a.y,a.x), transposed);
  a = mix(a, float2(1.0-a.x, a.y), flip);
  return a;
}

float2 inverseApply(float2 a, float transposed, float flip){
  a = mix(a, float2(1.0-a.x, a.y), flip);
  a = mix(a, float2(a.y, a.x), transposed);
  return a;
}
  
vertex VertexOut elastic_vertex(constant Vertex *vertices [[buffer(0)]],
                             constant VertUniform &u [[buffer(1)]],
                             uint vid [[vertex_id]]) {
  Vertex in = vertices[vid];
  VertexOut out;
  
  // convert to 0~1 square space with right edge curve
  
  float2 position = apply(in.position, u.transpose, u.flip);
  float2 touchPosition = apply(u.touchPosition - u.shift, u.transpose, u.flip);
  
//  Curve c = (Curve){sine, easeinout};
  Curve c = Curve(0.72,0.39,0.81,0.94);
  float y = c.solve(min(1.0, abs(touchPosition.y - position.y)));
  
  float updatedX = touchPosition.x * position.x;
  updatedX = mix(updatedX, position.x, y);
  Curve c2 = (Curve){sine, easeout};
  updatedX = mix(updatedX, position.x, c2.solve((1 - position.x) * touchPosition.x));
  
  // fold
  float foldFrequency = 30;
  float foldAlpha = (1 - clamp(touchPosition.x, 0.7, 1.0)) * 5;
  float foldX = (1 - clamp(touchPosition.x, 0.7, 1.0)) * 8;
  // from touchlocation -> 1 to farther away -> 0
  float foldMagnitude = (1.0 - min(1.0, (4-foldX)*(1-position.x) + 2*abs(position.y-touchPosition.y))) * foldAlpha;
  float fold = (sin(c2.solve(1.1-position.x) * foldFrequency)+1.0) / 2.0;
  
  out.shadowAlpha = fold * foldMagnitude * u.foldAlpha;
  
  // convert position back
  position.x = updatedX;
  position = inverseApply(position, u.transpose, u.flip) + u.shift;
  out.position = float4(position * 2.0 - 1.0, 0, 1);
  out.texCoord = float2(in.position.x, 1.0 - in.position.y);
  
  return out;
}

fragment float4 elastic_fragment(VertexOut vert [[stage_in]],
                              texture2d<float> frontTex [[ texture(0) ]],
                              texture2d<float> backTex [[ texture(1) ]]) {
  
  constexpr sampler textureSampler(coord::normalized,
                                   address::repeat,
                                   min_filter::linear,
                                   mag_filter::linear,
                                   mip_filter::linear );
  float3 colorF = frontTex.sample(textureSampler, vert.texCoord).rgb;
  colorF = mix(colorF.rgb, float3(0,0,0), vert.shadowAlpha); // mix in shadow
  return float4(colorF, 1);
}
