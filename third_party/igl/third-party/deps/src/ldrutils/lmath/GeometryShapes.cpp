/**
 * \file GeometryShapes.cpp
 * \brief
 *
 * Basic geometry shapes
 *
 * \author Sergey Kosarevsky, 2025
 * \author support@linderdaum.com   http://www.linderdaum.com   http://blog.linderdaum.com
 * https://github.com/corporateshark/ldrutils
 */

// clang-format off
#if !defined(_USE_MATH_DEFINES)
#  define _USE_MATH_DEFINES
#endif // _USE_MATH_DEFINES
// clang-format on

#include <assert.h>

#include "GeometryShapes.h"

using GeometryShapes::Vertex;

namespace {

class MeshBuilder final {
 public:
  explicit MeshBuilder(std::vector<Vertex>& vertices) : vertices_(vertices) {}
  void setNormal(GS_VEC3 n) {
    vtx_.normal = n;
  }
  void setTexCoord(GS_VEC3 uvw) {
    vtx_.uv = GS_VEC2(uvw.x, uvw.y);
  }
  void emitVertex(GS_VEC3 p) {
    assert(activeVertexCount_ < vertices_.size());
    vtx_.pos = p;
    vertices_[activeVertexCount_++] = vtx_;
  }
  void emitVertex(float x, float y, float z) {
    assert(activeVertexCount_ < vertices_.size());
    vtx_.pos = GS_VEC3(x, y, z);
    vertices_[activeVertexCount_++] = vtx_;
  }
  void emitVertex(GS_VEC2 uv, GS_VEC3 p) {
    assert(activeVertexCount_ < vertices_.size());
    vtx_.uv = uv;
    vtx_.pos = p;
    vertices_[activeVertexCount_++] = vtx_;
  }

 private:
  std::vector<Vertex>& vertices_;
  Vertex vtx_ = {};
  size_t activeVertexCount_ = 0;
};

GS_VEC2 projectOnSphere(GS_VEC3 v) {
  return GS_VEC2(float((atan2(v.y, v.x) + M_PI) / (2.0 * M_PI)), float((acos(v.z) + M_PI) / M_PI - 1.0));
}

} // namespace

std::vector<Vertex> GeometryShapes::createQuad2D(GS_VEC2 a, GS_VEC2 b, const float z) {
  std::vector<Vertex> mesh(4);

  MeshBuilder B(mesh);

  B.emitVertex({0, 0}, {a.x, a.y, z});
  B.emitVertex({0, 1}, {a.x, b.y, z});
  B.emitVertex({1, 0}, {b.x, a.y, z});
  B.emitVertex({1, 1}, {b.x, b.y, z});

  return mesh;
}

std::vector<GS_VEC3> createIcosahedronVertices(float r) {
  // http://www.opengl.org.ru/docs/pg/0208.html
  const float x = 0.525731112119133606f * r;
  const float z = 0.850650808352039932f * r;

  const GS_VEC3 v[] = {
      {-x, 0.0f, z},
      {x, 0.0f, z},
      {-x, 0.0f, -z},
      {x, 0.0f, -z},
      {0.0f, z, x},
      {0.0f, z, -x},
      {0.0f, -z, x},
      {0.0f, -z, -x},
      {z, x, 0.0f},
      {-z, x, 0.0f},
      {z, -x, 0.0f},
      {-z, -x, 0.0f},
  };

  const int indices[20][3] = {{0, 1, 4}, {0, 4, 9},  {9, 4, 5},  {4, 8, 5},  {4, 1, 8},  {8, 1, 10}, {8, 10, 3},
                              {5, 8, 3}, {5, 3, 2},  {2, 3, 7},  {7, 3, 10}, {7, 10, 6}, {7, 6, 11}, {11, 6, 0},
                              {0, 6, 1}, {6, 10, 1}, {9, 11, 0}, {9, 2, 11}, {9, 5, 2},  {7, 11, 2}};

  std::vector<GS_VEC3> res;
  res.reserve(60);

  for (int i = 0; i != 20; i++) {
    res.push_back(v[indices[i][0]]);
    res.push_back(v[indices[i][1]]);
    res.push_back(v[indices[i][2]]);
  }

  return res;
}

std::vector<Vertex> GeometryShapes::createIcosahedron(GS_VEC3 center, float radius) {
  std::vector<Vertex> mesh(60);

  MeshBuilder B(mesh);

  const std::vector<GS_VEC3> vertices = createIcosahedronVertices(radius);

  for (size_t i = 0; i != vertices.size(); i += 3) {
    const GS_VEC3 v1 = vertices[i + 0];
    const GS_VEC3 v2 = vertices[i + 1];
    const GS_VEC3 v3 = vertices[i + 2];

    const GS_VEC3 normal = normalize(cross(v2 - v1, v3 - v1));

    B.setNormal(normal);
    B.emitVertex(projectOnSphere(normalize(v1)), v1 + center);
    B.emitVertex(projectOnSphere(normalize(v2)), v2 + center);
    B.emitVertex(projectOnSphere(normalize(v3)), v3 + center);
  }

  return mesh;
}

std::vector<GS_VEC3> subdivide(const std::vector<GS_VEC3>& v) {
  std::vector<GS_VEC3> r;
  r.reserve(v.size() * 4);

  for (size_t i = 0; i != v.size(); i += 3) {
    const GS_VEC3 v1 = v[i + 0];
    const GS_VEC3 v2 = v[i + 1];
    const GS_VEC3 v3 = v[i + 2];

    const GS_VEC3 v12 = (v1 + v2) * 0.5f;
    const GS_VEC3 v23 = (v2 + v3) * 0.5f;
    const GS_VEC3 v13 = (v1 + v3) * 0.5f;

    r.push_back(v1);
    r.push_back(v12);
    r.push_back(v13);

    r.push_back(v12);
    r.push_back(v2);
    r.push_back(v23);

    r.push_back(v13);
    r.push_back(v23);
    r.push_back(v3);

    r.push_back(v13);
    r.push_back(v12);
    r.push_back(v23);
  }

  return r;
}

// somewhat inspired by gluDisk()
// https://gitlab.freedesktop.org/mesa/glu/-/blob/master/src/libutil/quad.c#L431
std::vector<Vertex> GeometryShapes::createDisk(const float innerRadius, const float outerRadius, const int numSlices) {
  struct SinCos {
    float sin_;
    float cos_;
  };

  const float startAngle = 0.0f;
  const float sweepAngle = 360.0f;
  const int loops = 30;

  std::vector<SinCos> angles;
  std::vector<Vertex> drawingData;

  const float deltaRadius = outerRadius - innerRadius;
  const float angleOffset = startAngle / 180.0f * M_PI;

  for (int i = 0; i <= numSlices; i++) {
    const float angle = static_cast<float>(angleOffset + ((M_PI * sweepAngle) / 180.0f) * static_cast<float>(i) / numSlices);
    angles.emplace_back(SinCos{sinf(angle), cosf(angle)});
  }

  if (sweepAngle == 360.0f) {
    angles[numSlices] = angles[0];
    angles[numSlices] = angles[0];
  }

  for (int j = 0; j < loops; j++) {
    const float radiusLow = outerRadius - deltaRadius * (static_cast<float>(j) / loops);
    const float radiusHigh = outerRadius - deltaRadius * (static_cast<float>(j + 1) / loops);

    const float texLow = radiusLow / outerRadius / 2;
    const float texHigh = radiusHigh / outerRadius / 2;

    for (int i = 0; i <= numSlices; i++) {
      const float sin = angles[i].sin_;
      const float cos = angles[i].cos_;

      drawingData.emplace_back(Vertex{GS_VEC3(radiusHigh * sin, radiusHigh * cos, 0.0f),
                                      GS_VEC2(texHigh * sin + 0.5f, texHigh * cos + 0.5f),
                                      GS_VEC3(0.0f, 0.0f, 1.0f)});
      drawingData.emplace_back(Vertex{
          GS_VEC3(radiusLow * sin, radiusLow * cos, 0.0f), GS_VEC2(texLow * sin + 0.5f, texLow * cos + 0.5f), GS_VEC3(0.0f, 0.0f, 1.0f)});
    }
  }

  return drawingData;
}

std::vector<Vertex> GeometryShapes::createOrbit(const float radius, const int subdivision) {
  std::vector<GS_VEC3> vertices;
  for (size_t i = 0; i < 360; i += (360 / subdivision)) {
    const float heading = static_cast<float>((M_PI / 180.0f) * i);
    vertices.emplace_back(cos(heading) * radius, sin(heading) * radius, 0.0f);
  }

  std::vector<Vertex> mesh(vertices.size() + 1); // add 1 extra vertex to close the loop

  MeshBuilder B(mesh);

  for (const auto& vertex : vertices) {
    B.emitVertex({0, 0}, vertex);
  }

  // add 1 extra vertex to close the loop
  B.emitVertex({0, 0}, vertices[0]);

  return mesh;
}

std::vector<Vertex> GeometryShapes::createIcoSphere(GS_VEC3 center, float radius, unsigned int subdivision) {
  std::vector<GS_VEC3> vertices = createIcosahedronVertices(radius);

  for (unsigned int i = 0u; i != subdivision; i++) {
    vertices = subdivide(vertices);
  }

  std::vector<Vertex> mesh(vertices.size());

  MeshBuilder B(mesh);

  for (size_t i = 0; i != vertices.size(); i += 3) {
    const GS_VEC3 v1 = normalize(vertices[i + 0]);
    const GS_VEC3 v2 = normalize(vertices[i + 1]);
    const GS_VEC3 v3 = normalize(vertices[i + 2]);

    B.setNormal(v1);
    B.emitVertex(projectOnSphere(v1), radius * v1 + center);
    B.setNormal(v2);
    B.emitVertex(projectOnSphere(v2), radius * v2 + center);
    B.setNormal(v3);
    B.emitVertex(projectOnSphere(v3), radius * v3 + center);
  }

  Vertex* v = mesh.data();

  for (size_t i = 0; i != vertices.size(); i += 3) {
    if (cross(GS_VEC3(v[i + 1].uv, 0.0f) - GS_VEC3(v[i + 0].uv, 0.0f), GS_VEC3(v[i + 2].uv, 0.0f) - GS_VEC3(v[i + 0].uv, 0.0f)).z > 0.0f) {
      if (v[i + 0].uv.x >= 0.75f)
        v[i + 0].uv.x -= 1.0f;
      if (v[i + 1].uv.x >= 0.75f)
        v[i + 1].uv.x -= 1.0f;
      if (v[i + 2].uv.x >= 0.75f)
        v[i + 2].uv.x -= 1.0f;
    }
  }

  return mesh;
}

std::vector<Vertex> GeometryShapes::createAxisAlignedBox(GS_VEC3 center, GS_VEC3 halfDiagonal) {
  std::vector<Vertex> mesh(36);

  MeshBuilder B(mesh);

  const float k = 1.0f;
  const GS_VEC3 uvwScale(1.0f, 1.0f, 1.0f);

  const GS_VEC3 min = center - halfDiagonal;
  const GS_VEC3 max = center + halfDiagonal;

  // top
  B.setNormal(k * GS_VEC3(0, 0, 1));

  B.setTexCoord(uvwScale * GS_VEC3(0, 0, 0));
  B.emitVertex(min.x, min.y, max.z);
  B.setTexCoord(uvwScale * GS_VEC3(1, 0, 0));
  B.emitVertex(max.x, min.y, max.z);
  B.setTexCoord(uvwScale * GS_VEC3(1, 1, 0));
  B.emitVertex(max.x, max.y, max.z);

  B.setTexCoord(uvwScale * GS_VEC3(1, 1, 0));
  B.emitVertex(max.x, max.y, max.z);
  B.setTexCoord(uvwScale * GS_VEC3(0, 1, 0));
  B.emitVertex(min.x, max.y, max.z);
  B.setTexCoord(uvwScale * GS_VEC3(0, 0, 0));
  B.emitVertex(min.x, min.y, max.z);

  // bottom
  B.setNormal(k * GS_VEC3(0, 0, -1));

  B.setTexCoord(uvwScale * GS_VEC3(0, 0, 0));
  B.emitVertex(min.x, min.y, min.z);
  B.setTexCoord(uvwScale * GS_VEC3(0, 1, 0));
  B.emitVertex(min.x, max.y, min.z);
  B.setTexCoord(uvwScale * GS_VEC3(1, 1, 0));
  B.emitVertex(max.x, max.y, min.z);

  B.setTexCoord(uvwScale * GS_VEC3(1, 1, 0));
  B.emitVertex(max.x, max.y, min.z);
  B.setTexCoord(uvwScale * GS_VEC3(1, 0, 0));
  B.emitVertex(max.x, min.y, min.z);
  B.setTexCoord(uvwScale * GS_VEC3(0, 0, 0));
  B.emitVertex(min.x, min.y, min.z);

  // left
  B.setNormal(k * GS_VEC3(0, 1, 0));

  B.setTexCoord(uvwScale * GS_VEC3(1, 0, 0));
  B.emitVertex(max.x, max.y, min.z);
  B.setTexCoord(uvwScale * GS_VEC3(0, 0, 0));
  B.emitVertex(min.x, max.y, min.z);
  B.setTexCoord(uvwScale * GS_VEC3(0, 1, 0));
  B.emitVertex(min.x, max.y, max.z);

  B.setTexCoord(uvwScale * GS_VEC3(0, 1, 0));
  B.emitVertex(min.x, max.y, max.z);
  B.setTexCoord(uvwScale * GS_VEC3(1, 1, 0));
  B.emitVertex(max.x, max.y, max.z);
  B.setTexCoord(uvwScale * GS_VEC3(1, 0, 0));
  B.emitVertex(max.x, max.y, min.z);

  // right
  B.setNormal(k * GS_VEC3(0, -1, 0));

  B.setTexCoord(uvwScale * GS_VEC3(0, 0, 0));
  B.emitVertex(min.x, min.y, min.z);
  B.setTexCoord(uvwScale * GS_VEC3(1, 0, 0));
  B.emitVertex(max.x, min.y, min.z);
  B.setTexCoord(uvwScale * GS_VEC3(1, 1, 0));
  B.emitVertex(max.x, min.y, max.z);

  B.setTexCoord(uvwScale * GS_VEC3(1, 1, 0));
  B.emitVertex(max.x, min.y, max.z);
  B.setTexCoord(uvwScale * GS_VEC3(0, 1, 0));
  B.emitVertex(min.x, min.y, max.z);
  B.setTexCoord(uvwScale * GS_VEC3(0, 0, 0));
  B.emitVertex(min.x, min.y, min.z);

  // front
  B.setNormal(k * GS_VEC3(1, 0, 0));

  B.setTexCoord(uvwScale * GS_VEC3(0, 0, 0));
  B.emitVertex(max.x, min.y, min.z);
  B.setTexCoord(uvwScale * GS_VEC3(1, 0, 0));
  B.emitVertex(max.x, max.y, min.z);
  B.setTexCoord(uvwScale * GS_VEC3(1, 1, 0));
  B.emitVertex(max.x, max.y, max.z);

  B.setTexCoord(uvwScale * GS_VEC3(1, 1, 0));
  B.emitVertex(max.x, max.y, max.z);
  B.setTexCoord(uvwScale * GS_VEC3(0, 1, 0));
  B.emitVertex(max.x, min.y, max.z);
  B.setTexCoord(uvwScale * GS_VEC3(0, 0, 0));
  B.emitVertex(max.x, min.y, min.z);

  // back
  B.setNormal(k * GS_VEC3(-1, 0, 0));

  B.setTexCoord(uvwScale * GS_VEC3(1, 0, 0));
  B.emitVertex(min.x, max.y, min.z);
  B.setTexCoord(uvwScale * GS_VEC3(0, 0, 0));
  B.emitVertex(min.x, min.y, min.z);
  B.setTexCoord(uvwScale * GS_VEC3(0, 1, 0));
  B.emitVertex(min.x, min.y, max.z);

  B.setTexCoord(uvwScale * GS_VEC3(0, 1, 0));
  B.emitVertex(min.x, min.y, max.z);
  B.setTexCoord(uvwScale * GS_VEC3(1, 1, 0));
  B.emitVertex(min.x, max.y, max.z);
  B.setTexCoord(uvwScale * GS_VEC3(1, 0, 0));
  B.emitVertex(min.x, max.y, min.z);

  return mesh;
}

void GeometryShapes::addAxisAlignedBox(std::vector<Vertex>& v, GS_VEC3 center, GS_VEC3 halfDiagonal) {
  const std::vector<Vertex> mesh = createAxisAlignedBox(center, halfDiagonal);

  v.insert(v.end(), mesh.begin(), mesh.end());
}
