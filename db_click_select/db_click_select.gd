@tool
extends EditorPlugin

##用法：
##将整个文件夹放入res://addons目录下，勾选项目设置->插件
##在：前后鼠标双击，会选中：后的代码块。
##在不含：的语句末尾点击会选中当前语句所属的代码块。

var _timer: Timer
var _hooked := {} # {instance_id: true}

func _enter_tree() -> void:
	# 周期性扫描，把所有 TextEdit 挂上 gui_input 监听
	_timer = Timer.new()
	_timer.wait_time = 0.5
	_timer.autostart = true
	_timer.timeout.connect(_hook_code_edits)
	add_child(_timer)

func _exit_tree() -> void:
	if is_instance_valid(_timer):
		_timer.stop()
		_timer.queue_free()
	_hooked.clear()

func _hook_code_edits() -> void:
	var se := get_editor_interface().get_script_editor()
	if se == null:
		return
	var edits := []
	_collect_edits(se, edits)
	for ed:TextEdit in edits:
		var id = ed.get_instance_id()
		if not _hooked.has(id):
			# 绑定 gui_input；把 ed 作为额外参数传入
			ed.gui_input.connect(Callable(self, "_on_code_gui_input").bind(ed))
			_hooked[id] = true

func _collect_edits(n: Node, out: Array) -> void:
	for c in n.get_children():
		if c is TextEdit:
			out.append(c)
		_collect_edits(c, out)

func _on_code_gui_input(event: InputEvent, ed: TextEdit) -> void: #

	if not (event is InputEventMouseButton):
		return

	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT or not mb.double_click or not mb.pressed:
		return
	var pos = ed.get_line_column_at_pos(ed.get_local_mouse_pos())#x 是列号，y 是行号。
	var line = pos.y
	if _end_with_colon(ed.get_line(line)) and ed.get_line(line).substr(pos.x-1,2).contains(":"):#点击位置是：前后
		print("11111")
		ed.accept_event()
		call_deferred("_select_block_at_line", ed, line)
		#_select_block_at_line(ed, line)
	elif ed.get_line(line).length() == pos.x: #点击一行的末尾
		print("=====")
		ed.accept_event()
		var up_line = _find_nearest_colon_line(ed, line)
		call_deferred("_select_block_at_line", ed, up_line)

## 向上找到最近的同级以冒号结尾的行
func _find_nearest_colon_line(ed: TextEdit,line: int) -> int:
	var str = ed.get_line(line)
	if _end_with_colon(str) or _is_blank(str) or _is_annotation(str):
		return line
	var up_line = line
	var indent = _indent_of(str)
	while not _end_with_colon(ed.get_line(up_line)) or _indent_of(ed.get_line(up_line)) >= indent:
		up_line -= 1
		if up_line < 0:
			break
	
	return up_line

func _select_block_at_line(ed: TextEdit, line: int) -> void:
	if line < 0 or line >= ed.get_line_count():
		return
	# 若当前行为空行，返回
	var cur := line
	if cur >= 0 and _is_blank(ed.get_line(cur)):
		return
	if not _end_with_colon(ed.get_line(cur)):
		return

	#获取下一行的缩进
	cur += 1
	while _is_blank(ed.get_line(cur)) || _is_annotation(ed.get_line(cur)): #是空行或注释行就继续下移
		cur += 1

	var cur_indent := _indent_of(ed.get_line(cur))

	var line_gap = 0
	var next_line = cur+1
	while _indent_of(ed.get_line(next_line+line_gap)) >= cur_indent || _is_blank(ed.get_line(next_line+line_gap)) || _is_annotation(ed.get_line(next_line+line_gap)):
		line_gap += 1
		if cur + line_gap > ed.get_line_count(): #预防选择最后一个函数时会死循环♻️
			break
	
	while _is_blank(ed.get_line(cur+line_gap)) || _is_annotation(ed.get_line(cur+line_gap)):
		line_gap = line_gap - 1
	
	var end_line = cur + line_gap
	ed.select(cur,cur_indent,end_line,ed.get_line(end_line).length())
	
	#print(cur,":",cur_indent,":",end_line,":",ed.get_line(end_line).length())


func _is_blank(s: String) -> bool:
	return s.strip_edges() == ""

#是否是注释行
func _is_annotation(s: String) -> bool:
	return s.strip_edges().begins_with("#")

#去除#的注释内容后， 是否以冒号结尾
func _end_with_colon(s: String) -> bool:
	return s.split("#")[0].strip_edges().ends_with(":")

# 缩进的数量
func _indent_of(s: String) -> int:
	var n := 0
	for ch in s:
		if ch == "\t":
			n += 1
		else:
			break
	return n
