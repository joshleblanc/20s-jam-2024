require "lib/drecs/lib/drecs.rb"

include Drecs::Main

WIDTH = 1024
HEIGHT = 720
OFFSET = 128

SCALE = 2
ROWS = (HEIGHT / SCALE).to_i
COLS = (WIDTH / SCALE).to_i

component :position, x: 0, y: 0
component :size, w: WIDTH / COLS, h: HEIGHT / ROWS
component :label, text: "lorem ipsum"
component :hovered
component :bordered
component :solid, { r: 0, g: 0, b: 0 }
component :clickable, target: :none
component :range, value: 1
component :health, value: 100
component :cost, value: 25
component :team, value: 1
component :resource, value: 0
component :sprite, path: ""
component :timer, value: 20

entity :button, :position, :size, :label, :bordered, :label, :clickable, solid: { r: 255, g: 255, b: 0 }
entity :cell, :position, :bordered, :size, clickable: { target: :unit }, solid: { r: 255, g: 255, b: 255 }
entity :light_unit, :range, :health, :cost, :team, :position, :size, :bordered, sprite: { path: "sprites/hexagon/indigo.png" }
entity :base, :health, :team, :position, :size, :bordered, sprite: { path: "sprites/triangle/equilateral/blue.png" }
entity :gold, :resource, :team 
entity :timer, :timer

system :resource_gain_system, :resource do |entities|
  entities.each do |entity|
    if state.tick_count % 10 == 0 
      entity.resource.value += 1
    end
  end
end

system :resource_display_system, :resource, :team do |entities|
  entities.each do |entity|
    x = if entity.team.value == 0
      0
    else
      WIDTH + OFFSET
    end

    x += 32
    y = 32

    outputs.sprites << { x: x, y: y, w: 64, h: 64, path: "sprites/circle/blue.png" }
    outputs.labels << { x: x + 32, y: y, text: entity.resource.value, r: 255, g: 0, b: 255, alignment_enum: 1 }
  end
end

system :draw_units_system, :sprite, :team, :position, :size do |entities|
  entities.each do |e| 
    if e.entity_name == :base 
      log "drawing base, #{e.size}"
    end
    outputs.sprites << rect(e).merge(path: e.sprite.path)
  end
end

system :setup_game do
  ROWS.times do |row|
    COLS.times do |col|
      create_entity(:cell, {
        position: { x: ((WIDTH / COLS) * col) + OFFSET, y: (HEIGHT / ROWS) * row },
      })
    end
  end

  remove_system :setup_game 
end

system :click_system, :clickable, :position, :size do |entities|
  entities.each do |e|
    if inputs.mouse.click && inputs.mouse.click.point.inside_rect?(rect(e))
      if e.clickable.target == :exit
        exit
      elsif e.clickable.target == :play
        set_world :game
      elsif e.clickable.target == :unit
        
        # TODO: track team and selected unit
        team = 0
        selected_unit = { cost: { value: 25 }}

        resource = state.entities.find { _1.team.value == team && _1.entity_name == :gold }
        if resource&.resource&.value >= selected_unit&.cost&.value
          resource.resource.value -= selected_unit.cost.value
          create_entity(:light_unit, team: { value: 0 }, position: e.position, size: e.size)
          delete_entity(e)
        end
      end
    end
  end
end

system :hoverable_system, :position, :size do |entities| 
  entities.each do |e|
    if inputs.mouse.position.inside_rect? rect(e)
      add_component e, :hovered
    else
      remove_component e, :hovered
    end
  end
end

system :label_system, :label, :position, :label, :size do |entities|
  entities.each do |e|
    offsets = { x: 0, y: 0 }
    offsets.x = e.size.w / 2
    offsets.y = e.size.h / 2
    outputs.labels << {
      x: e.position.x + offsets.x,
      y: e.position.y + offsets.y, 
      alignment_enum: 1,
      vertical_alignment_enum: 1,
      text: e.label.text 
    }
  end
end

system :solid_system, :solid do |entities|
  entities.each do |e|
    if has_components? e, :hovered
      outputs.solids << rect(e).merge(r: e.solid.r % 64, g: e.solid.g % 64, b: e.solid.b % 64)
    else 
      outputs.solids << rect(e).merge(r: e.solid.r, g: e.solid.g, b: e.solid.b)
    end
  end
end

system :border_system, :bordered do |entities|
  entities.each do |e|
    outputs.borders << rect(e).merge(r: 0, g: 0, b: 0)
  end
end

system :debug do |entities|
  outputs.primitives << gtk.framerate_diagnostics_primitives
end

system :timer_system, :timer do |entities|
  entities.each do 
    if state.tick_count % 60 == 0 
      _1.timer.value -= 1
      if _1.timer.value == 0
        set_world :menu
      end
    end
  end
end

system :render_timer_system, :timer do |entities|
  entities.each do
    outputs.labels << {
      x: 1280 / 2,
      alignment_enum: 1,
      y: 0.from_top,
      text: _1.timer.value,
      size_enum: 40
    }
  end
end

world :menu, 
    systems: [:hoverable_system, :solid_system, :label_system, :click_system, :debug], 
      entities: [
        { button: { position: { x: 540, y: 385 }, size: { w: 200, h: 50 }, label: { text: "Play" }, clickable: { target: :play }, as: :play_button } },
        { button: { position: { x: 540, y: 285 }, size: { w: 200, h: 50 }, label: { text: "Exit" }, clickable: { target: :exit }, as: :exit_button } },
      ]

world :game,
      systems: [ 
        :click_system, :draw_units_system, :hoverable_system, :setup_game, :debug, :solid_system, :border_system, :resource_gain_system, :resource_display_system,
        :timer_system, :render_timer_system
      ],
      entities: [
        { gold: { team: { value: 0 } }},
        { gold: { team: { value: 1 } }},
        { timer: { timer: { value: 20 }}},
        { 
          base: { 
            team: { value: 0 },
            position: {
              x: OFFSET,
              y: (HEIGHT / 2) - (HEIGHT / ROWS) / 2
            }
          }
        },
        { 
          base: { 
            team: { value: 1 },
            position: {
              x: (OFFSET + (WIDTH / COLS)).from_right,
              y: (HEIGHT / 2) - (HEIGHT / ROWS) / 2
            }
          }
        },
      ]

def rect(entity)
  { x: entity.position.x, y: entity.position.y, w: entity.size.w, h: entity.size.h }
end

def tick args
  if args.state.tick_count == 0 
    set_world :menu
  end
  process_systems args 
end
