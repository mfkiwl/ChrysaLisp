%include 'inc/func.inc'
%include 'inc/font.inc'
%include 'inc/sdl2.inc'

	fn_function gui/font_deinit
		;get font statics
		static_bind gui_font, statics, r15

		;free all text in the cache
		vp_lea [r15 + ft_statics_text_lists], r10
		vp_lea [r10 + ft_buckets_size], r11
		loop_start
			loop_flist_forward r10, r14, r13
				vp_cpy r14, r12
				ln_remove_fnode r14, r13
				sdl_destroy_texture [r12 + ft_text_texture]
				s_call sys_mem, free, {r12}
			loop_end
			vp_add ptr_size, r10
		loop_until r10, ==, r11

		;free all fonts in the cache
		loop_flist_forward r15 + ft_statics_font_list, r14, r13
			vp_cpy r14, r12
			ln_remove_fnode r14, r13
			ttf_close_font [r12 + ft_font_handle]
			s_call sys_mem, free, {r12}
		loop_end
		vp_ret

	fn_function_end
