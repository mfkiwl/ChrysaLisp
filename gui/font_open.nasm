%include 'inc/func.ninc'
%include 'inc/font.ninc'
%include 'inc/string.ninc'
%include 'inc/sdl2.ninc'
%include 'inc/task.ninc'

def_func gui/font_open
	;inputs
	;r0 = font name
	;r1 = point size
	;outputs
	;r0 = 0 if error, else font cache entry
	;trashes
	;all but r4

	def_struct local
		long local_font
		long local_points
		long local_handle
	def_struct_end

	;save inputs
	vp_sub local_size, r4
	set_src r0, r1
	set_dst [r4 + local_font], [r4 + local_points]
	map_src_to_dst

	;get font statics
	f_bind gui_font, statics, r5

	;search font list
	loop_flist_forward r5, ft_statics_font_flist, r5, r5
		vp_cpy [r4 + local_points], r0
		continueif r0, !=, [r5 + ft_font_points]
		f_call sys_string, compare, {&[r5 + ft_font_name], [r4 + local_font]}, {r0}
	loop_until r0, ==, 0

	;did we find it ?
	vp_cpy r5, r0
	vpif r5, ==, 0
		;no so try open it
		f_call sys_task, callback, {$kernel_callback, r4}
		vp_cpy [r4 + local_handle], r0
	endif
	vp_add local_size, r4
	vp_ret

kernel_callback:
	;inputs
	;r0 = user data
	;trashes
	;all but r4

	;align stack
	vp_cpy r4, r15
	vp_and -16, r4

	;save input
	vp_cpy r0, r14

	;get font statics
	f_bind gui_font, statics, r5

	;search font list
	loop_flist_forward r5, ft_statics_font_flist, r5, r5
		vp_cpy [r14 + local_points], r0
		continueif r0, !=, [r5 + ft_font_points]
		f_call sys_string, compare, {&[r5 + ft_font_name], [r14 + local_font]}, {r0}
	loop_until r0, ==, 0

	;did we find it ?
	vp_cpy r5, r0
	vpif r5, ==, 0
		ttf_open_font [r14 + local_font], [r14 + local_points]
		vpif r0, !=, 0
			vp_cpy r0, r5
			f_call sys_string, length, {[r14 + local_font]}, {r1}
			f_call sys_mem, alloc, {&[r1 + ft_font_size + 1]}, {r13, _}
			assert r0, !=, 0

			vp_cpy [r14 + local_points], r0
			vp_cpy r0, [r13 + ft_font_points]
			vp_cpy r5, [r13 + ft_font_handle]
			f_call sys_string, copy, {[r14 + local_font], &[r13 + ft_font_name]}, {_, _}

			;fill in ascent, descent and height
			ttf_font_ascent [r13 + ft_font_handle]
			vp_cpy r0, [r13 + ft_font_ascent]
			ttf_font_descent [r13 + ft_font_handle]
			vp_cpy r0, [r13 + ft_font_descent]
			ttf_font_height [r13 + ft_font_handle]
			vp_cpy r0, [r13 + ft_font_height]

			vp_cpy r13, r0
			f_bind gui_font, statics, r5
			ln_add_fnode r5 + ft_statics_font_flist, r0, r1
		endif
	endif
	vp_cpy r0, [r14 + local_handle]

	vp_cpy r15, r4
	vp_ret

def_func_end
