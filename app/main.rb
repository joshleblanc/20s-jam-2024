require "lib/drecs/lib/drecs.rb"

include Drecs::Main

component :position, x: 0, y: 0
component :size, w: 32, h: 32
component :label, text: "lorem ipsum"
component :hovered
component :bordered
component :clickable, target: :none

entity :button, :position, :size, :label, :bordered, :solid, :label, :clickable

system :click_system, :clickable, :position, :size do |entities|
  entities.each do |e|
    if inputs.mouse.click && inputs.mouse.click.point.inside_rect?(rect(e))
      if e.clickable.target == :exit
        exit
      elsif e.clickable.target == :play
        puts "Play!"
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

system :solid_system, :bordered do |entities|
  entities.each do |e|
    if has_components? e, :hovered
      outputs.solids << rect(e).merge(r: 0, g: 255, b: 255)
    else 
      outputs.solids << rect(e).merge(r: 255, g: 0, b: 255)
    end
  end
end

system :debug do |entities|
  outputs.primitives << gtk.framerate_diagnostics_primitives
end

world :menu, 
      systems: [:hoverable_system, :solid_system, :label_system, :click_system, :debug], 
      entities: [
        { button: { position: { x: 540, y: 385 }, size: { w: 200, h: 50 }, label: { text: "Play" }, clickable: { target: :play }, as: :play_button } },
        { button: { position: { x: 540, y: 285 }, size: { w: 200, h: 50 }, label: { text: "Exit" }, clickable: { target: :exit }, as: :exit_button } },
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
