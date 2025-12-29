package sokol_imgui

import sg "../sokol/gfx"
import sapp "../sokol/app"
import imgui "../imgui"

@(private)
Frame_Desc :: struct {
	width:      i32,
	height:     i32,
	delta_time: f64,
	dpi_scale:  f32,
}

@(private)
Vs_Params :: struct {
	disp_size: [2]f32,
	_pad:      [8]u8,
}

State :: struct {
	is_inited:     bool,
	ctx:           ^imgui.Context,
	dpi_scale:     f32,
	vertex_buffer: sg.Buffer,
	index_buffer:  sg.Buffer,
	shader:        sg.Shader,
	pipe:          sg.Pipeline,
	vertices:      []imgui.DrawVert,
	indices:       []imgui.DrawIdx,
	font_img:      sg.Image,
	font_view:     sg.View,
	font_smp:      sg.Sampler,
	dock_id:       imgui.ID,
}

@(private)
g_state: ^State

@(private)
MAX_VERTICES :: 65536

setup :: proc(state: ^State, flags: imgui.ConfigFlags = {}) {
	g_state = state
	imgui.CHECKVERSION()

	if (imgui.GetCurrentContext() == nil) {
		g_state.ctx = imgui.CreateContext()
	}

	io := imgui.GetIO()
	io.ConfigFlags += flags
	io.BackendFlags += {.RendererHasVtxOffset}

	g_state.vertex_buffer = sg.make_buffer({
		usage = { vertex_buffer = true, stream_update = true },
		size = MAX_VERTICES * size_of(imgui.DrawVert),
		label = "simgui-vertices",
	})

	g_state.index_buffer = sg.make_buffer({
		usage = {index_buffer = true, stream_update = true},
		size = MAX_VERTICES * 3 * size_of(imgui.DrawIdx),
		label = "simgui-indices",
	})

	g_state.font_smp = sg.make_sampler({
		min_filter = .LINEAR,
		mag_filter = .LINEAR,
		wrap_u = .CLAMP_TO_EDGE,
		wrap_v = .CLAMP_TO_EDGE,
		label = "simgui-font-sampler",
	})

	g_state.shader = sg.make_shader(get_shader_desc(sg.query_backend()))

	pipe_desc := sg.Pipeline_Desc{
		shader = g_state.shader,
		index_type = .UINT16 when size_of(imgui.DrawIdx) == 2 else .UINT32,
		label = "simgui-pipeline",
	}
	pipe_desc.layout.buffers[0].stride = size_of(imgui.DrawVert)
	pipe_desc.layout.attrs[0] = {
		offset = i32(offset_of(imgui.DrawVert, pos)),
		format = .FLOAT2,
	}
	pipe_desc.layout.attrs[1] = {
		offset = i32(offset_of(imgui.DrawVert, uv)),
		format = .FLOAT2,
	}
	pipe_desc.layout.attrs[2] = {
		offset = i32(offset_of(imgui.DrawVert, col)),
		format = .UBYTE4N,
	}
	pipe_desc.colors[0] = {
		write_mask = .RGBA,
		blend = {
			enabled = true,
			src_factor_rgb = .SRC_ALPHA,
			dst_factor_rgb = .ONE_MINUS_SRC_ALPHA,
			src_factor_alpha = .SRC_ALPHA,
			dst_factor_alpha = .ONE_MINUS_SRC_ALPHA,
		},
	}
	g_state.pipe = sg.make_pipeline(pipe_desc)

	build_font_atlas()

	g_state.is_inited = true
}

hot_reloaded :: proc(state: ^State) {
	g_state = state
	imgui.SetCurrentContext(g_state.ctx)
}

shutdown :: proc() {
	if (g_state.is_inited == false) {
		return
	}

	imgui.DestroyContext()

	sg.destroy_pipeline(g_state.pipe)
	sg.destroy_shader(g_state.shader)
	sg.destroy_buffer(g_state.index_buffer)
	sg.destroy_buffer(g_state.vertex_buffer)
}

new_frame :: proc(desc: Frame_Desc) {
	io := imgui.GetIO()
	if (desc.dpi_scale != 0) {
	 g_state.dpi_scale = desc.dpi_scale	
	} else {
	 g_state.dpi_scale = 1.0
	}

	io.DisplaySize.x = f32(desc.width) / g_state.dpi_scale
	io.DisplaySize.y = f32(desc.height) / g_state.dpi_scale
	io.DeltaTime = f32(desc.delta_time) if desc.delta_time > 0 else 1.0 / 60.0

	imgui.NewFrame()
	g_state.dock_id = imgui.DockSpaceOverViewport(0, nil, { .PassthruCentralNode })
}

render :: proc() {
	imgui.Render()
	draw_data := imgui.GetDrawData()
	if draw_data == nil || draw_data.CmdListsCount == 0 {
		return
	}

	io := imgui.GetIO()
	fb_width := i32(io.DisplaySize.x * g_state.dpi_scale)
	fb_height := i32(io.DisplaySize.y * g_state.dpi_scale)
	if (fb_width <= 0 || fb_height <= 0) {
		return
	}

	sg.apply_pipeline(g_state.pipe)
	vs_params := Vs_Params {
		disp_size = {io.DisplaySize.x, io.DisplaySize.y},
	}
	sg.apply_uniforms(0, { ptr = &vs_params, size = size_of(vs_params) })

	for cl_idx in 0 ..< draw_data.CmdListsCount {
		cl := (cast([^]^imgui.DrawList)draw_data.CmdLists.Data)[cl_idx]

		vb_offset: i32 = 0
		ib_offset: i32 = 0
		
		num_verts := cl.VtxBuffer.Size
		if num_verts > 0 {
			vb_offset = sg.append_buffer(g_state.vertex_buffer, {
				ptr = cl.VtxBuffer.Data,
				size = uint(num_verts) * size_of(imgui.DrawVert),
			})
		}

		num_indices := cl.IdxBuffer.Size
		if num_indices > 0 {
			ib_offset = sg.append_buffer(g_state.index_buffer, {
				ptr = cl.IdxBuffer.Data,
				size = uint(num_indices) * size_of(imgui.DrawIdx),
			})
		}

		bindings := sg.Bindings{
			vertex_buffers = { 0 = g_state.vertex_buffer },
			vertex_buffer_offsets = { 0 = vb_offset },
			index_buffer = g_state.index_buffer,
			index_buffer_offset = ib_offset,
		}

		for cmd_idx in 0 ..< cl.CmdBuffer.Size {
			cmd := &(cast([^]imgui.DrawCmd)cl.CmdBuffer.Data)[cmd_idx]

			if cmd.UserCallback != nil {
				cmd.UserCallback(cl, cmd)
				sg.apply_pipeline(g_state.pipe)
				sg.apply_uniforms(0, { ptr = &vs_params, size = size_of(vs_params) })
				continue
			}

			clip_x := i32(cmd.ClipRect.x * g_state.dpi_scale)
			clip_y := i32(cmd.ClipRect.y * g_state.dpi_scale)
			clip_w := i32((cmd.ClipRect.z - cmd.ClipRect.x) * g_state.dpi_scale)
			clip_h := i32((cmd.ClipRect.w - cmd.ClipRect.y) * g_state.dpi_scale)

			if clip_x < fb_width && clip_y < fb_height && clip_w > 0 && clip_h > 0 {
				sg.apply_scissor_rect(clip_x, clip_y, clip_w, clip_h, true)

				tex_view := texture_view_from_imtextureid(cmd.TextureId)
				tex_smp := sampler_from_imtextureid(cmd.TextureId)
				bindings.views[0] = tex_view
				bindings.samplers[0] = tex_smp
				sg.apply_bindings(bindings)

				sg.draw(i32(cmd.IdxOffset), i32(cmd.ElemCount), 1)
			}
		}
	}

	sg.apply_scissor_rect(0, 0, fb_width, fb_height, true)
}

main_dock_id :: proc() -> imgui.ID {
	return g_state.dock_id
}

@(private)
build_font_atlas :: proc() {
	io := imgui.GetIO()

	pixels: ^u8
	width, height: i32
	imgui.FontAtlas_GetTexDataAsRGBA32(io.Fonts, &pixels, &width, &height)

	if g_state.font_img.id != 0 {
		sg.destroy_view(g_state.font_view)
		sg.destroy_image(g_state.font_img)
	}

	g_state.font_img = sg.make_image({
		width = width,
		height = height,
		pixel_format = .RGBA8,
		label = "simgui-font",
		data = {
			mip_levels = {
				0 = {
					ptr = pixels,
					size = uint(width * height * 4),
				},
			},
		},
	})

	g_state.font_view = sg.make_view({
		texture = { image = g_state.font_img },
		label = "simgui-font-view",
	})

	io.Fonts.TexID = imtextureid_with_sampler(g_state.font_view, g_state.font_smp)
}

@(private)
imtextureid_with_sampler :: proc(tex_view: sg.View, smp: sg.Sampler) -> imgui.TextureID {
	view_id := u64(tex_view.id)
	smp_id := u64(smp.id)
	return imgui.TextureID(uintptr((view_id << 32) | smp_id))
}

@(private)
texture_view_from_imtextureid :: proc(imtex_id: imgui.TextureID) -> sg.View {
	id := u64(uintptr(imtex_id))
	return sg.View{id = u32(id >> 32)}
}

@(private)
sampler_from_imtextureid :: proc(imtex_id: imgui.TextureID) -> sg.Sampler {
	id := u64(uintptr(imtex_id))
	return sg.Sampler{id = u32(id & 0xFFFFFFFF)}
}

@(private)
get_shader_desc :: proc(backend: sg.Backend) -> sg.Shader_Desc {
	desc: sg.Shader_Desc
	desc.label = "simgui-shader"

	desc.uniform_blocks[0] = {
		stage = .VERTEX,
		size = size_of(Vs_Params),
		glsl_uniforms = {
			0 = { glsl_name = "vs_params", type = .FLOAT2 },
		},
	}

	desc.views[0] = {
		texture = {
			stage = .FRAGMENT,
			image_type = ._2D,
			sample_type = .FLOAT,
		},
	}
	desc.samplers[0] = {
		stage = .FRAGMENT,
		sampler_type = .FILTERING,
	}
	desc.texture_sampler_pairs[0] = {
		stage = .FRAGMENT,
		view_slot = 0,
		sampler_slot = 0,
		glsl_name = "tex_smp",
	}

	#partial switch backend {
	case .METAL_MACOS:
		desc.vertex_func.source = VS_SOURCE_METAL
		desc.fragment_func.source = FS_SOURCE_METAL
	}

	return desc
}

@(private)
VS_SOURCE_METAL :: `
#include <metal_stdlib>
using namespace metal;
struct vs_params {
	float2 disp_size;
};
struct vs_in {
	float2 pos [[attribute(0)]];
	float2 uv [[attribute(1)]];
	float4 col [[attribute(2)]];
};
struct vs_out {
	float4 pos [[position]];
	float2 uv;
	float4 color;
};
vertex vs_out _main(vs_in inp [[stage_in]], constant vs_params& params [[buffer(0)]]) {
	vs_out outp;
	outp.pos = float4(((inp.pos/params.disp_size) - 0.5) * float2(2.0, -2.0), 0.5, 1.0);
	outp.uv = inp.uv;
	outp.color = inp.col;
	return outp;
}
`

@(private)
FS_SOURCE_METAL :: `
#include <metal_stdlib>
using namespace metal;
struct fs_in {
	float2 uv;
	float4 color;
};
fragment float4 _main(fs_in inp [[stage_in]], texture2d<float> tex [[texture(0)]], sampler smp [[sampler(0)]]) {
	return tex.sample(smp, inp.uv) * inp.color;
}
`

@(private)
map_keycode :: proc(key: sapp.Keycode) -> imgui.Key {
    #partial switch key {
    case .SPACE:         return .Space
    case .APOSTROPHE:    return .Apostrophe
    case .COMMA:         return .Comma
    case .MINUS:         return .Minus
    case .PERIOD:        return .Period
    case .SLASH:         return .Slash
    case ._0:            return ._0
    case ._1:            return ._1
    case ._2:            return ._2
    case ._3:            return ._3
    case ._4:            return ._4
    case ._5:            return ._5
    case ._6:            return ._6
    case ._7:            return ._7
    case ._8:            return ._8
    case ._9:            return ._9
    case .SEMICOLON:     return .Semicolon
    case .EQUAL:         return .Equal
    case .A:             return .A
    case .B:             return .B
    case .C:             return .C
    case .D:             return .D
    case .E:             return .E
    case .F:             return .F
    case .G:             return .G
    case .H:             return .H
    case .I:             return .I
    case .J:             return .J
    case .K:             return .K
    case .L:             return .L
    case .M:             return .M
    case .N:             return .N
    case .O:             return .O
    case .P:             return .P
    case .Q:             return .Q
    case .R:             return .R
    case .S:             return .S
    case .T:             return .T
    case .U:             return .U
    case .V:             return .V
    case .W:             return .W
    case .X:             return .X
    case .Y:             return .Y
    case .Z:             return .Z
    case .LEFT_BRACKET:  return .LeftBracket
    case .BACKSLASH:     return .Backslash
    case .RIGHT_BRACKET: return .RightBracket
    case .GRAVE_ACCENT:  return .GraveAccent
    case .ESCAPE:        return .Escape
    case .ENTER:         return .Enter
    case .TAB:           return .Tab
    case .BACKSPACE:     return .Backspace
    case .INSERT:        return .Insert
    case .DELETE:        return .Delete
    case .RIGHT:         return .RightArrow
    case .LEFT:          return .LeftArrow
    case .DOWN:          return .DownArrow
    case .UP:            return .UpArrow
    case .PAGE_UP:       return .PageUp
    case .PAGE_DOWN:     return .PageDown
    case .HOME:          return .Home
    case .END:           return .End
    case .CAPS_LOCK:     return .CapsLock
    case .SCROLL_LOCK:   return .ScrollLock
    case .NUM_LOCK:      return .NumLock
    case .PRINT_SCREEN:  return .PrintScreen
    case .PAUSE:         return .Pause
    case .F1:            return .F1
    case .F2:            return .F2
    case .F3:            return .F3
    case .F4:            return .F4
    case .F5:            return .F5
    case .F6:            return .F6
    case .F7:            return .F7
    case .F8:            return .F8
    case .F9:            return .F9
    case .F10:           return .F10
    case .F11:           return .F11
    case .F12:           return .F12
    case .KP_0:          return .Keypad0
    case .KP_1:          return .Keypad1
    case .KP_2:          return .Keypad2
    case .KP_3:          return .Keypad3
    case .KP_4:          return .Keypad4
    case .KP_5:          return .Keypad5
    case .KP_6:          return .Keypad6
    case .KP_7:          return .Keypad7
    case .KP_8:          return .Keypad8
    case .KP_9:          return .Keypad9
    case .KP_DECIMAL:    return .KeypadDecimal
    case .KP_DIVIDE:     return .KeypadDivide
    case .KP_MULTIPLY:   return .KeypadMultiply
    case .KP_SUBTRACT:   return .KeypadSubtract
    case .KP_ADD:        return .KeypadAdd
    case .KP_ENTER:      return .KeypadEnter
    case .KP_EQUAL:      return .KeypadEqual
    case .LEFT_SHIFT:    return .LeftShift
    case .LEFT_CONTROL:  return .LeftCtrl
    case .LEFT_ALT:      return .LeftAlt
    case .LEFT_SUPER:    return .LeftSuper
    case .RIGHT_SHIFT:   return .RightShift
    case .RIGHT_CONTROL: return .RightCtrl
    case .RIGHT_ALT:     return .RightAlt
    case .RIGHT_SUPER:   return .RightSuper
    case .MENU:          return .Menu
    case:                return .None
    }
}

@(private)
update_modifiers :: proc(mods: u32) {
	io := imgui.GetIO()
	imgui.IO_AddKeyEvent(io, .ImGuiMod_Ctrl, mods & sapp.MODIFIER_CTRL != 0)
	imgui.IO_AddKeyEvent(io, .ImGuiMod_Shift, mods & sapp.MODIFIER_SHIFT != 0)
	imgui.IO_AddKeyEvent(io, .ImGuiMod_Alt, mods & sapp.MODIFIER_ALT != 0)
	imgui.IO_AddKeyEvent(io, .ImGuiMod_Super, mods & sapp.MODIFIER_SUPER != 0)
}

handle_event :: proc(ev: ^sapp.Event) {
	io := imgui.GetIO()

	#partial switch ev.type {
	case .FOCUSED:
		imgui.IO_AddFocusEvent(io, true)

	case .UNFOCUSED:
		imgui.IO_AddFocusEvent(io, false)

	case .MOUSE_DOWN:
		update_modifiers(ev.modifiers)
		mouse_x := ev.mouse_x / g_state.dpi_scale
		mouse_y := ev.mouse_y / g_state.dpi_scale
		imgui.IO_AddMousePosEvent(io, mouse_x, mouse_y)
		imgui.IO_AddMouseButtonEvent(io, i32(ev.mouse_button), true)

	case .MOUSE_UP:
		update_modifiers(ev.modifiers)
		mouse_x := ev.mouse_x / g_state.dpi_scale
		mouse_y := ev.mouse_y / g_state.dpi_scale
		imgui.IO_AddMousePosEvent(io, mouse_x, mouse_y)
		imgui.IO_AddMouseButtonEvent(io, i32(ev.mouse_button), false)

	case .MOUSE_MOVE:
		mouse_x := ev.mouse_x / g_state.dpi_scale
		mouse_y := ev.mouse_y / g_state.dpi_scale
		imgui.IO_AddMousePosEvent(io, mouse_x, mouse_y)

	case .MOUSE_SCROLL:
		update_modifiers(ev.modifiers)
		imgui.IO_AddMouseWheelEvent(io, ev.scroll_x, ev.scroll_y)

	case .KEY_DOWN, .KEY_UP:
		update_modifiers(ev.modifiers)
		down := ev.type == .KEY_DOWN
		imgui_key := map_keycode(ev.key_code)
		imgui.IO_AddKeyEvent(io, imgui_key, down)

	case .CHAR:
		if ev.char_code >= 32 {
			imgui.IO_AddInputCharacter(io, ev.char_code)
		}
	}
}
