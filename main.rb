# frozen_string_literal: true

# rubocop:disable Style/GlobalVars

require 'ruby2d'
require 'pry'
require 'pry-nav'
require 'matrix'

$width = 1080.0
$height = 720.0
$d = 100.0
$translation_pace = 0.1
$rotation_pace = 0.07
$pressed = false
$ox = Matrix.column_vector([1.0, 0.0, 0.0])
$oy = Matrix.column_vector([0.0, 1.0, 0.0])
$oz = Matrix.column_vector([0.0, 0.0, 1.0])

class Connection
  attr_accessor :a, :b

  def initialize(a, b)
    @a = a
    @b = b
  end
end

$vfov = 90.0 * Math::PI / 180.0
$hfov = $vfov * 4.0 / 3.0

$transformation_matrix = Matrix[
  [1, 0, 0, 0],
  [0, 1, 0, 0],
  [0, 0, 1, 0],
  [0, 0, 0, 1]
    ]

set width: $width, height: $height

points = [
  # first layer
  Matrix.column_vector([1.5, 1.5, 0.0, 1.0]),

  # second layer
  Matrix.column_vector([0.0, 2.0, 1.0, 1.0]),
  Matrix.column_vector([1.0, 3.0, 1.0, 1.0]),
  Matrix.column_vector([2.0, 3.0, 1.0, 1.0]),
  Matrix.column_vector([3.0, 2.0, 1.0, 1.0]),
  Matrix.column_vector([3.0, 1.0, 1.0, 1.0]),
  Matrix.column_vector([2.0, 0.0, 1.0, 1.0]),
  Matrix.column_vector([1.0, 0.0, 1.0, 1.0]),
  Matrix.column_vector([0.0, 1.0, 1.0, 1.0]),

  # third layer
  Matrix.column_vector([0.75, 1.75, 1.5, 1.0]),
  Matrix.column_vector([1.25, 2.25, 1.5, 1.0]),
  Matrix.column_vector([1.75, 2.25, 1.5, 1.0]),
  Matrix.column_vector([2.25, 1.75, 1.5, 1.0]),
  Matrix.column_vector([2.25, 1.25, 1.5, 1.0]),
  Matrix.column_vector([1.75, 0.75, 1.5, 1.0]),
  Matrix.column_vector([1.25, 0.75, 1.5, 1.0]),
  Matrix.column_vector([0.75, 1.25, 1.5, 1.0])
]

connections = [
  # first second layer
  Connection.new(0, 1),
  Connection.new(0, 2),
  Connection.new(0, 3),
  Connection.new(0, 4),
  Connection.new(0, 5),
  Connection.new(0, 6),
  Connection.new(0, 7),
  Connection.new(0, 8),
  Connection.new(0, 8),

  # second layer
  Connection.new(1, 2),
  Connection.new(2, 3),
  Connection.new(3, 4),
  Connection.new(4, 5),
  Connection.new(5, 6),
  Connection.new(6, 7),
  Connection.new(7, 8),
  Connection.new(8, 1),

  # second third layer
  Connection.new(1, 9),
  Connection.new(2, 10),
  Connection.new(3, 11),
  Connection.new(4, 12),
  Connection.new(5, 13),
  Connection.new(6, 14),
  Connection.new(7, 15),
  Connection.new(8, 16),

  # third layer
  Connection.new(9, 10),
  Connection.new(10, 11),
  Connection.new(11, 12),
  Connection.new(12, 13),
  Connection.new(13, 14),
  Connection.new(14, 15),
  Connection.new(15, 16),
  Connection.new(16, 9)
]

def project_point(point)
  result = Matrix.column_vector([0.0, 0.0])
  result[0, 0] = (point[0, 0] * $d) / point[2, 0]
  result[1, 0] = (point[1, 0] * $d) / point[2, 0]
  result
end

def translate_point(point, translation_vector)
  result = Matrix.column_vector([0.0, 0.0, 0.0, 1.0])
  result[0, 0] = point[0, 0] + translation_vector[0, 0]
  result[1, 0] = point[1, 0] + translation_vector[1, 0]
  result[2, 0] = point[2, 0] + translation_vector[2, 0]

  result
end

def rotation_matrix(axis_vector, angle)
  vx = axis_vector[0, 0] * Math.sin(angle / 2.0)
  vy = axis_vector[1, 0] * Math.sin(angle / 2.0)
  vz = axis_vector[2, 0] * Math.sin(angle / 2.0)
  s = Math.cos(angle / 2.0)

  Matrix[[(1.0 - 2.0 * vy**2 - 2.0 * vz**2), (2.0 * vx * vy - 2.0 * s * vz),  (2.0 * vx * vz + 2.0 * s * vy),  0.0],
         [(2.0 * vx * vy + 2.0 * s * vz),  (1.0 - 2.0 * vx**2 - 2.0 * vz**2), (2.0 * vy * vz - 2.0 * s * vx),  0.0],
         [(2.0 * vx * vz - 2.0 * s * vy),  (2.0 * vy * vz + 2.0 * s * vx), (1.0 - 2.0 * vx**2 - 2.0 * vy**2), 0.0],
         [0.0, 0.0, 0.0, 1.0]
]
end

def rotate_point(point, rotation_axis, angle)
  rot_mtr = rotation_matrix(rotation_axis, angle)
  rot_mtr * point
end

def rotate_point_for_camera(point)
  $transformation_matrix * point
end

def reset_camera
  $transformation_matrix = Matrix[
    [1, 0, 0, 0],
    [0, 1, 0, 0],
    [0, 0, 1, 0],
    [0, 0, 0, 1]
      ]
  $vfov = 90.0 * Math::PI / 180.0
  $hfov = $vfov * 4.0 / 3.0
end

def translate_matrix(x, y, z)
  Matrix[
    [1, 0, 0, x],
    [0, 1, 0, y],
    [0, 0, 1, z],
    [0, 0, 0, 1]
  ]
end

gui_v_fov = Text.new(
  "Vertical FOV: #{($vfov * 180.0 / Math::PI).round(2)}",
  x: 150, y: 530,
  z: 10
)
gui_h_fov = Text.new(
  "Horizontal FOV: #{($hfov * 180.0 / Math::PI).round(2)}",
  x: 150, y: 550,
  z: 10
)
gui_debug = Text.new(
  'debug:',
  x: 150, y: 600,
  z: 10
)

points.map! do |point|
  point = rotate_point(point, Matrix.column_vector([1.0, 0.0, 0.0]), -1.57)
  point = translate_point(point, Matrix.column_vector([0.0, -1.25, 4.0]))
  point
end

render do
  projected_points = []

  on :key_down do |event|
    gui_v_fov.text = "Vertical FOV: #{($vfov * 180.0 / Math::PI).round(2)}"
    gui_h_fov.text = "Horizontal FOV: #{($hfov * 180.0 / Math::PI).round(2)}"

    unless $pressed
      gui_debug.text = "debug: #{event.key}"

      if event.key == 'w'
        $transformation_matrix = translate_matrix(0, 0, -$translation_pace) * $transformation_matrix
      elsif event.key == 's'
        $transformation_matrix = translate_matrix(0, 0, $translation_pace) * $transformation_matrix
      elsif event.key == 'a'
        $transformation_matrix = translate_matrix($translation_pace, 0, 0) * $transformation_matrix
      elsif event.key == 'd'
        $transformation_matrix = translate_matrix(-$translation_pace, 0, 0) * $transformation_matrix
      elsif event.key == 'z'
        $transformation_matrix = translate_matrix(0, $translation_pace, 0) * $transformation_matrix
      elsif event.key == 'x'
        $transformation_matrix = translate_matrix(0, -$translation_pace, 0) * $transformation_matrix
      elsif event.key == 'left'
        $transformation_matrix = rotation_matrix($oy, $rotation_pace) * $transformation_matrix
      elsif event.key == 'right'
        $transformation_matrix = rotation_matrix($oy, -$rotation_pace) * $transformation_matrix
      elsif event.key == 'down'
        $transformation_matrix = rotation_matrix($ox, -$rotation_pace) * $transformation_matrix
      elsif event.key == 'up'
        $transformation_matrix = rotation_matrix($ox, $rotation_pace) * $transformation_matrix
      elsif event.key == '['
        $transformation_matrix = rotation_matrix($oz, -$rotation_pace) * $transformation_matrix
      elsif event.key == ']'
        $transformation_matrix = rotation_matrix($oz, $rotation_pace) * $transformation_matrix
      elsif event.key == '='
        $vfov += $rotation_pace
        $hfov = $vfov * 4.0 / 3.0
      elsif event.key == '-'
        $vfov -= $rotation_pace
        $hfov = $vfov * 4.0 / 3.0
      elsif event.key == 'r'
        reset_camera
      end
    end

    $pressed = true
  end
  on :key_up do |_event|
    $pressed = false
  end
  points.map! do |point|
    rotated_for_camera = rotate_point_for_camera(point)
    projected_points << if !rotated_for_camera[2, 0].positive?
                          nil
                        else
                          project_point(rotated_for_camera)
                        end

    point
  end

  connections.each do |c|
    next if projected_points[c.a].nil? || projected_points[c.b].nil?

    vertical_limit = $d * Math.tan($vfov / 2)
    horizontal_limit = $d * Math.tan($hfov / 2)
    Line.draw(x1: (projected_points[c.a][0, 0] / horizontal_limit / 2.0 + 0.5) * $width,
              y1: $height - (projected_points[c.a][1, 0] / vertical_limit / 2.0 + 0.5) * $height,
              x2: (projected_points[c.b][0, 0] / horizontal_limit / 2.0 + 0.5) * $width,
              y2: $height - (projected_points[c.b][1, 0] / vertical_limit / 2.0 + 0.5) * $height,
              width: 1,
              color: [
                [1, 0, 0, 1.0],
                [1, 0, 0, 1.0],
                [1, 0, 0, 1.0],
                [1, 0, 0, 1.0]
              ])
  end

  sleep(0.1)
end

show
