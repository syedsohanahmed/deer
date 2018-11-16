import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:tasking/domain/entity/todo_entity.dart';
import 'package:tasking/presentation/screen/archive_list/archive_list_screen.dart';
import 'package:tasking/presentation/screen/todo_detail/todo_detail_screen.dart';
import 'package:tasking/presentation/screen/todo_list/todo_list_actions.dart';
import 'package:tasking/presentation/shared/helper/date_formatter.dart';
import 'package:tasking/presentation/shared/resources.dart';
import 'package:tasking/presentation/shared/widgets/buttons.dart';
import 'package:tasking/presentation/shared/widgets/tile.dart';

import 'todo_list_bloc.dart';
import 'todo_list_state.dart';

class TodoListScreen extends StatefulWidget {
  final String title;

  const TodoListScreen({Key key, this.title})
      : assert(title != null),
        super(key: key);

  @override
  _TodoListScreenState createState() => _TodoListScreenState();
}

class _TodoListScreenState extends State<TodoListScreen> {
  // Place variables here
  TodoListBloc _bloc;
  TextEditingController _todoNameController;
  ScrollController _todoListScrollController;

  @override
  void initState() {
    super.initState();
    _bloc = TodoListBloc();
    _todoNameController = TextEditingController();
    _todoListScrollController = ScrollController();
  }

  @override
  void dispose() {
    super.dispose();
    _bloc.dispose();
  }

  // Place methods here
  void _archiveTodo(TodoEntity todo) {
    _bloc.actions.add(PerformOnTodo(operation: Operation.archive, todo: todo));
  }

  void _addTodo(TodoEntity todo) {
    _bloc.actions.add(PerformOnTodo(operation: Operation.add, todo: todo));

    // scrolls to the bottom of TodoList
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _todoListScrollController.animateTo(
        _todoListScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  void _showDetails(TodoEntity todo) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => TodoDetailScreen(todo: todo, editable: true),
    ));
  }

  void _showArchive() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => ArchiveListScreen(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      initialData: _bloc.initialState,
      stream: _bloc.state,
      builder: (context, snapshot) {
        return _buildUI(snapshot.data);
      },
    );
  }

  Widget _buildUI(TodoListState state) {
    // Build your root view here
    return Scaffold(
      appBar: AppBar(
        iconTheme: IconThemeData(color: AppColors.pink4),
        title: Text(widget.title),
        centerTitle: true,
        actions: <Widget>[
          IconButton(
            icon: Icon(Icons.done_all),
            tooltip: 'Archive',
            onPressed: _showArchive,
          ),
          const SizedBox(width: 8.0),
        ],
      ),
      body: SafeArea(top: true, bottom: true, child: _buildBody(state)),
    );
  }

  Widget _buildBody(TodoListState state) {
    return Container(
      decoration: BoxDecoration(gradient: AppColors.pinkGradient),
      child: Column(
        children: <Widget>[
          Expanded(
            child: ListView.builder(
              itemCount: state.todos.length,
              controller: _todoListScrollController,
              itemBuilder: (context, index) {
                final todo = state.todos[index];
                return Dismissible(
                  key: Key(todo.addedDate.toIso8601String()),
                  background: _buildDismissibleBackground(leftToRight: true),
                  secondaryBackground: _buildDismissibleBackground(leftToRight: false),
                  onDismissed: (_) => _archiveTodo(todo),
                  child: TodoTile(
                    todo: todo,
                    onTap: () => _showDetails(todo),
                  ),
                );
              },
            ),
          ),
          _TodoAdder(
            onAdd: _addTodo,
            showError: state.todoNameHasError,
            todoNameController: _todoNameController,
          ),
        ],
      ),
    );
  }

  Widget _buildDismissibleBackground({@required bool leftToRight}) {
    final alignment = leftToRight ? Alignment.centerLeft : Alignment.centerRight;
    final colors = leftToRight ? [AppColors.pink2, AppColors.white1] : [AppColors.white1, AppColors.pink2];

    return Container(
      child: Text(
        'Done',
        style: TextStyle().copyWith(color: AppColors.white1, fontSize: 20.0),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      alignment: alignment,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
      ),
    );
  }
}

class _TodoAdder extends StatefulWidget {
  final TextEditingController todoNameController;
  final AddTaskCallback onAdd;
  final bool showError;

  const _TodoAdder({
    Key key,
    @required this.todoNameController,
    @required this.onAdd,
    @required this.showError,
  })  : assert(todoNameController != null),
        assert(onAdd != null),
        assert(showError != null),
        super(key: key);

  @override
  _TodoAdderState createState() => _TodoAdderState();
}

class _TodoAdderState extends State<_TodoAdder> {
  final double _collapsedHeight = 96;
  final double _expandedHeight = 180;
  // final double _expandedHeight = 240;

  bool _isExpanded;
  double _height;
  DateTime _dueDate;

  @override
  void initState() {
    super.initState();
    _isExpanded = false;
    _height = _collapsedHeight;
  }

  void _selectDate() async {
    // set initialDate to tomorrow by default
    final tomorrow = DateTime.now().add(Duration(days: 1));

    final date = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? tomorrow,
      firstDate: DateTime(1970),
      lastDate: DateTime(2050),
    );

    if (date != null) {
      setState(() {
        _dueDate = date;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final children = [
      const SizedBox(height: 4.0),
      _buildHeader(),
      const SizedBox(height: 4.0),
      _buildAdder(),
      const SizedBox(height: 16.0),
    ];

    if (_isExpanded) {
      children.add(_buildBody());
    }

    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      curve: Curves.easeOut,
      height: _height,
      decoration: BoxDecoration(
        boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 10.0)],
        color: AppColors.white1,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24.0),
          topRight: Radius.circular(24.0),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }

  Widget _buildHeader() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        setState(() {
          _isExpanded = !_isExpanded;
          _height = _isExpanded ? _expandedHeight : _collapsedHeight;
        });
      },
      child: Center(
        child: Icon(_isExpanded ? Icons.arrow_drop_down : Icons.arrow_drop_up),
      ),
    );
  }

  Widget _buildAdder() {
    return Row(
      mainAxisSize: MainAxisSize.max,
      children: <Widget>[
        const SizedBox(width: 18.0),
        Expanded(
          child: TextField(
            controller: widget.todoNameController,
            maxLength: 50,
            maxLengthEnforced: true,
            maxLines: null,
            textInputAction: TextInputAction.done,
            textCapitalization: TextCapitalization.sentences,
            style: TextStyle().copyWith(fontSize: 16.0, color: AppColors.black1),
            decoration: InputDecoration.collapsed(
              border: UnderlineInputBorder(),
              hintText: widget.showError ? 'Name can\'t be empty' : 'New Todo',
              hintStyle: TextStyle().copyWith(
                color: widget.showError ? AppColors.pink5 : AppColors.pink3,
              ),
            ),
            onSubmitted: (_) {
              widget.onAdd(_buildTodo());
              widget.todoNameController.clear();
            },
          ),
        ),
        const SizedBox(width: 16.0),
        RoundButton(
          text: 'Add',
          onPressed: () {
            widget.onAdd(_buildTodo());
            widget.todoNameController.clear();
          },
        ),
        const SizedBox(width: 16.0),
      ],
    );
  }

  Widget _buildBody() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: _buildDate(),
    );
  }

  Widget _buildDate() {
    return GestureDetector(
      onTap: _selectDate,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24.0),
          border: Border.all(color: AppColors.pink4),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Due by:',
              style: TextStyle().copyWith(fontSize: 12.0, color: AppColors.pink4),
            ),
            const SizedBox(height: 8.0),
            Row(
              mainAxisSize: MainAxisSize.max,
              children: <Widget>[
                const SizedBox(width: 20.0),
                Text(
                  DateFormatter.safeFormatDays(_dueDate),
                ),
                Expanded(child: const SizedBox(width: 20.0)),
                Text(
                  DateFormatter.safeFormatFull(_dueDate),
                  textAlign: TextAlign.right,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  TodoEntity _buildTodo() {
    return TodoEntity(
      name: widget.todoNameController.text,
      addedDate: DateTime.now(),
      dueDate: _dueDate,
    );
  }
}

typedef void AddTaskCallback(TodoEntity task);
