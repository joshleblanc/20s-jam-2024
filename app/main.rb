require "lib/drecs/lib/drecs.rb"

include Drecs::Main

WIDTH = 1024
HEIGHT = 720
OFFSET = 128

SCALE = 80
ROWS = (HEIGHT / SCALE).to_i
COLS = (WIDTH / SCALE).to_i

component :position, x: 0, y: 0
component :size, w: WIDTH / COLS, h: HEIGHT / ROWS
component :label, text: "lorem ipsum"
component :hovered
component :bordered
component :can_attack
component :on_cooldown
component :solid, { r: 0, g: 0, b: 0 }
component :clickable, target: :none
component :range, value: 1
component :health, current: 100, full: 100
component :cost, value: 25
component :team, value: 1
component :resource, value: 0
component :sprite, path: ""
component :damage, value: 0
component :attack_speed, value: 1, cooldown: 60, current_cooldown: 0
component :timer, value: 20
component :unit, name: :light_unit
component :speed, x: 0, y: 0
component :accel, value: 1
component :target, value: nil
component :rotation, value: 0


entity :button, :position, :size, :label, :bordered, :label, :clickable, solid: { r: 255, g: 255, b: 0 }
entity :cell, :position, :bordered, :size, clickable: { target: :unit }, solid: { r: 255, g: 255, b: 255 }

entity(
  :light_unit, 
  :on_cooldown, 
  :cost, 
  :team, 
  :position, 
  :size, 
  :rotation,
  :bordered, 
  health: { current: 100, full: 100 },
  range: { value: SCALE * 10 }, 
  damage: { value: 10 }, 
  attack_speed: { value: 1 }, 
  sprite: { path: "sprites/hexagon/indigo.png" }
)

entity(
  :medium_unit, 
  :on_cooldown, 
  :cost, 
  :team, 
  :position, 
  :size, 
  :rotation,
  :bordered,
  health: { full: 175, current: 175},
  range: { value: SCALE * 5 }, 
  damage: { value: 20 }, 
  attack_speed: { value: 2 }, 
  sprite: { path: "sprites/square/indigo.png" }
)

entity(
  :heavy_unit, 
  :on_cooldown, 
  :health, 
  :cost, 
  :team, 
  :position, 
  :size, 
  :rotation,
  :bordered, 
  health: { full: 250, current: 250 },
  range: { value: SCALE * 1 }, 
  damage: { value: 45 }, 
  attack_speed: { value: 3 }, 
  sprite: { path: "sprites/circle/indigo.png" }
)

entity :base, :health, :team, :position, :size, :bordered, sprite: { path: "sprites/triangle/equilateral/blue.png" }
entity :gold, :resource, :team 
entity :timer, :timer

entity :projectile, :speed, :position, :size, :solid, :target, :accel, :damage

entity :selected_unit, :cost, :team, :unit

system :health_system, :health do |entities| 
  entities.each do |e|
    if e.health.current <= 0 
      delete_entity(e)
      create_entity(:cell, {
        position: e.position.clone,
        size: e.size.clone
      })
    end
  end
end

system :render_selected_unit_system, :cost, :team, :unit do |entities|
  entities.each do |entity|
    x = if entity.team.value == 0
      0
    else
      WIDTH + OFFSET
    end

    x += 32
    y = 256

    actual_unit = Drecs::ENTITIES[entity.unit.name]
    outputs.sprites << { x: x, y: y, w: 64, h: 64, path: actual_unit.sprite.path }
    outputs.labels << { x: x + 32, y: y, text: entity.unit.name, alignment_enum: 1, size_enum: 0 }
    outputs.labels << { x: x + 32, y: y - 25, text: entity.cost.value, alignment_enum: 1, size_enum: 0 }

  end
end

system :hotkeys_system do
  if inputs.keyboard.one
    ent = state.entities.find { _1.entity_name == :selected_unit && _1.team.value == 0 }
    ent.unit.name = :light_unit
    ent.cost.value = 25
  elsif inputs.keyboard.two
    ent = state.entities.find { _1.entity_name == :selected_unit && _1.team.value == 0 }
    ent.unit.name = :medium_unit
    ent.cost.value = 50
  elsif inputs.keyboard.three
    ent = state.entities.find { _1.entity_name == :selected_unit && _1.team.value == 0 }
    ent.unit.name = :heavy_unit
    ent.cost.value = 75
  end
end

system :projectile_system, :speed, :position, :target, :accel do |entities|
  entities.each do |e|
    mid1 = geometry.rect_center_point(rect(e))
    mid2 = geometry.rect_center_point(rect(e.target.value))
    dir = geometry.vec2_normalize(vec2_sub(mid1, mid2))

    e.speed = vec2_add(e.speed, vec2_mul(dir, e.accel.value))

    e.position = vec2_add(e.position, e.speed)

    if rect(e).inside_rect?(rect(e.target.value))
      e.target.value.health.current -= e.damage.value
      delete_entity(e)
    end
  end
end

system :can_attack_system, :attack_speed, :on_cooldown do |entities|
  entities.each do |e|
    e.attack_speed.current_cooldown -= 1
    if e.attack_speed.current_cooldown <= 0
      remove_component(e, :on_cooldown)
      add_component(e, :can_attack)
    end
  end
end

system :attack_system, :team, :position, :range, :damage, :attack_speed, :can_attack do |entities|
  entities.each do |e|
    mid1 = geometry.rect_center_point rect(e)
    
    in_range = entities.find do 
      mid2 = geometry.rect_center_point rect(_1)
      dist = geometry.distance(mid1, mid2)

      dist <= e.range.value && _1.team.value != e.team.value && e != _1
    end

    if in_range 
      e.attack_speed.current_cooldown = e.attack_speed.cooldown
      remove_component(e, :can_attack)
      add_component(e, :on_cooldown)
      e.rotation.value = geometry.angle_to(mid1, geometry.rect_center_point(rect(in_range)))
      create_entity(:projectile, {
        speed: { value: 1 },
        target: { value: in_range },
        size: { w: e.damage.value, h: e.damage.value },
        position: mid1,
        solid: team_color(e.team.value),
        damage: { value: e.damage.value }
      })
    else 
      e.rotation.value += 1
    end
  end
end

system :resource_gain_system, :resource do |entities|
  entities.each do |entity|
    if state.tick_count % 5 == 0 
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

system :draw_units_system, :sprite, :team, :position, :size, :health do |entities|
  entities.each do |e| 
    outputs.solids << rect(e).merge(**team_color(e.team.value), h: (e.health.current / e.health.full) * e.size.h)
    outputs.sprites << rect(e).merge(path: e.sprite.path, blendmode_enum: 2, angle: e.rotation&.value || 0)
  end
end

system :setup_game do
  base_row = (ROWS / 2).to_i
  ROWS.times do |row|
    COLS.times do |col|
      if row == base_row && col == 0
        create_entity(:base, {
          team: { value: 0 },
          position: { x: ((WIDTH / COLS) * col) + OFFSET, y: (HEIGHT / ROWS) * row },
        })
      elsif row == base_row && col == COLS - 1
        create_entity(:base, {
          team: { value: 1 },
          position: { x: ((WIDTH / COLS) * col) + OFFSET, y: (HEIGHT / ROWS) * row },
        })
      else 
        create_entity(:cell, {
          position: { x: ((WIDTH / COLS) * col) + OFFSET, y: (HEIGHT / ROWS) * row },
        })
      end

    end
  end

  remove_system :setup_game 
end

system :click_system, :clickable, :position, :size do |entities|
  entities.each do |e|
    if inputs.mouse.click && inputs.mouse.inside_rect?(rect(e))
      if e.clickable.target == :exit
        exit
      elsif e.clickable.target == :play
        set_world :game
      elsif e.clickable.target == :unit
        
        # TODO: track team and selected unit
        team = inputs.mouse.button_left ? 0 : 1
        selected_unit = state.entities.find { _1.entity_name == :selected_unit && _1.team.value == team }

        resource = state.entities.find { _1.team.value == team && _1.entity_name == :gold }
        if resource&.resource&.value >= selected_unit&.cost&.value
          resource.resource.value -= selected_unit.cost.value
          log selected_unit
          create_entity(selected_unit.unit.name, team: { value: team }, position: e.position, size: e.size)
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

system :solid_system, :solid, :position, :size do |entities|
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
        :timer_system, :render_timer_system, :can_attack_system, :attack_system, :projectile_system, :health_system,
        :render_selected_unit_system, :hotkeys_system
      ],
      entities: [
        { gold: { team: { value: 0 } }},
        { gold: { team: { value: 1 } }},
        { timer: { timer: { value: 20 }}},
        { selected_unit: { team: { value: 0 }, unit: { name: :light_unit }}},
        { selected_unit: { team: { value: 1 }, unit: { name: :light_unit }}},
      ]

def rect(entity)
  { x: entity.position.x, y: entity.position.y, w: entity.size.w, h: entity.size.h }
end

def team_color(team)
  if team == 0
    { r: 255, g: 0, b: 0 }
  else 
    { r: 0, g: 0, b: 255 }
  end
end

def vec2_add(a, b)
  { x: a.x + b.x, y: a.y + b.y }
end

def vec2_sub(a, b) 
  { x: b.x - a.x, y: b.y - a.y }
end

def vec2_mul(a, b)
  { x: a.x * b, y: a.y * b }
end

def tick args
  if args.state.tick_count == 0 
    set_world :menu
  end
  process_systems args 
end
