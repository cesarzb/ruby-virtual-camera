# frozen_string_literal: true

require 'ruby2d'
require 'pry'
require 'pry-nav'
require 'matrix'

$width = 1080.0
$height = 720.0
$d = 100.0
$translation_pace = 0.1
$rotation_pace = 0.07
$camera_translation_precision = 1
$camera_rotation_precision = 2
$pressed = false
$combined_rotation_matrix = nil

# ox = Matrix.column_vector([1.0, 0.0, 0.0])
#   oy = Matrix.column_vector([0.0, 1.0, 0.0])
#   oz = Matrix.column_vector([0.0, 0.0, 1.0])
#   quant_angle = 0.07 * 5

class Connection
  attr_accessor :a, :b

  def initialize(a, b)
    @a = a
    @b = b
  end
end

$camera = {
  x: 0.0,
  y: 0.0,
  z: 0.0,
  # OX
  pitch: 0.0,
  # OY
  yaw: 0.0,
  # OZ
  roll: 0.0,
  vfov: 90 * Math::PI / 180,
  hfov: 113 * Math::PI / 180
}

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
  point -= Matrix.column_vector([$camera[:x], $camera[:y], $camera[:z], 0.0])
  result = Matrix.column_vector([0.0, 0.0])
  result[0, 0] = (point[0, 0] * $d) / point[2, 0]
  result[1, 0] = (point[1, 0] * $d) / point[2, 0]

  result + Matrix.column_vector([$camera[:x], $camera[:y]])
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

def generate_rotation_matrix_for_camera
  rot_mtr_yaw = rotation_matrix(Matrix.column_vector([0.0, 1.0, 0.0]), -$camera[:yaw])
  rot_mtr_pitch = rotation_matrix(Matrix.column_vector([1.0, 0.0, 0.0]), -$camera[:pitch])
  rot_mtr_roll = rotation_matrix(Matrix.column_vector([0.0, 0.0, 1.0]), -$camera[:roll])
  $combined_rotation_matrix = rot_mtr_roll * rot_mtr_pitch * rot_mtr_yaw
end

def rotate_point_for_camera(point)
  point -= Matrix.column_vector([$camera[:x], $camera[:y], $camera[:z], 0.0])
  $combined_rotation_matrix * point + Matrix.column_vector([$camera[:x], $camera[:y], $camera[:z], 0.0])
end

def reset_camera
  $camera[:x] = 0.0
  $camera[:y] = 0.0
  $camera[:z] = 0.0

  $camera[:yaw] = 0.0
  $camera[:pitch] = 0.0
  $camera[:roll] = 0.0
end

gui_yaw = Text.new(
  "Camera yaw: #{$camera[:yaw]}",
  x: 150, y: 470,
  z: 10
)
gui_pitch = Text.new(
  "Camera pitch: #{$camera[:pitch]}",
  x: 150, y: 490,
  z: 10
)
gui_roll = Text.new(
  "Camera roll: #{$camera[:roll]}",
  x: 150, y: 510,
  z: 10
)
gui_x = Text.new(
  "Camera x: #{$camera[:x]}",
  x: 150, y: 530,
  z: 10
)
gui_y = Text.new(
  "Camera y: #{$camera[:y]}",
  x: 150, y: 550,
  z: 10
)
gui_z = Text.new(
  "Camera z: #{$camera[:z]}",
  x: 150, y: 570,
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
  visible_connections = connections
  projected_points = []

  on :key_down do |event|
    gui_yaw.text = "Camera yaw: #{$camera[:yaw]}"
    gui_pitch.text = "Camera pitch: #{$camera[:pitch]}"
    gui_roll.text = "Camera roll: #{$camera[:roll]}"
    gui_x.text = "Camera x: #{$camera[:x]}"
    gui_y.text = "Camera y: #{$camera[:y]}"
    gui_z.text = "Camera z: #{$camera[:z]}"

    unless $pressed
      gui_debug.text = "debug: #{event.key}"

      if event.key == 'w'
        $camera[:z] += $translation_pace * Math.cos($camera[:yaw])
        $camera[:x] += $translation_pace * Math.sin($camera[:yaw])
      elsif event.key == 's'
        $camera[:z] -= $translation_pace * Math.cos($camera[:yaw])
        $camera[:x] -= $translation_pace * Math.sin($camera[:yaw])
      elsif event.key == 'a'
        $camera[:z] += $translation_pace * Math.sin($camera[:yaw])
        $camera[:x] -= $translation_pace * Math.cos($camera[:yaw])
      elsif event.key == 'd'
        $camera[:z] -= $translation_pace * Math.sin($camera[:yaw])
        $camera[:x] += $translation_pace * Math.cos($camera[:yaw])
      elsif event.key == 'z'
        $camera[:y] -= $translation_pace
      elsif event.key == 'x'
        $camera[:y] += $translation_pace
      elsif event.key == 'left'
        $camera[:yaw] -= $rotation_pace
      elsif event.key == 'right'
        $camera[:yaw] += $rotation_pace
      elsif event.key == 'down'
        $camera[:pitch] += $rotation_pace
      elsif event.key == 'up'
        $camera[:pitch] -= $rotation_pace
      elsif event.key == '['
        $camera[:roll] += $rotation_pace
      elsif event.key == ']'
        $camera[:roll] -= $rotation_pace
      elsif event.key == 'r'
        reset_camera
      end
    end
    $pressed = true
  end
  on :key_up do |_event|
    $pressed = false
  end
  generate_rotation_matrix_for_camera
  points.map! do |point|
    rotated_for_camera = rotate_point_for_camera(point)
    projected_points << if rotated_for_camera[2, 0] < $camera[:z]
                          nil
                        else
                          project_point(rotated_for_camera)
                        end

    point
  end

  # visible_connections.each_with_index do |c, _index|
  #   next if projected_points[c.a].nil? || projected_points[c.b].nil?

  #   Line.draw(x1: projected_points[c.a][0, 0] + 0.5 * $width,
  #             y1: $height - projected_points[c.a][1, 0] - 0.5 * $height,
  #             x2: projected_points[c.b][0, 0] + 0.5 * $width,
  #             y2: $height - projected_points[c.b][1, 0] - 0.5 * $height,
  #             width: 1,
  #             color: [
  #               [1, 0, 0, 1.0],
  #               [1, 0, 0, 1.0],
  #               [1, 0, 0, 1.0],
  #               [1, 0, 0, 1.0]
  #             ])
  # end

  visible_connections.each_with_index do |c, _index|
    next if projected_points[c.a].nil? || projected_points[c.b].nil?

    vertical_limit = $d * Math.tan($camera[:vfov] / 2)
    horizontal_limit = $d * Math.tan($camera[:hfov] / 2)
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
