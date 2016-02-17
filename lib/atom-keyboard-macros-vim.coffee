{CompositeDisposable} = require 'atom'
AtomKeyboardMacros = require 'atom-keyboard-macros'
HiddenInputViewModel = require './hidden-input-view-model'

# enum
class InputMode
  @None: 0
  @Execute: 1
  @Record: 2

module.exports = AtomKeyboardMacrosVim =
  subscriptions: null

  activate: (state) ->
    # Events subscribed to in atom's system can be easily cleaned up with a CompositeDisposable
    @subscriptions = new CompositeDisposable

    # Register command that toggles this view
    @subscriptions.add atom.commands.add 'atom-workspace', 'atom-keyboard-macros-vim:toggle_record_macro_vim': => @toggle_record_macro_vim()
    @subscriptions.add atom.commands.add 'atom-workspace', 'atom-keyboard-macros-vim:execute_macro_vim': => @execute_macro_vim()

    # make event listener
    @eventListener = @keyboardEventHandler.bind(this)

    AtomKeyboardMacros.activate(state)

    vim_mode = atom.packages.getActivePackage('vim-mode')
    @vim_module = vim_mode?.mainModule

  deactivate: ->
    AtomKeyboardMacros.deactivate()
    @model = null
    @subscriptions.dispose()
    window.removeEventListener('keydown', @eventListener, true)

  serialize: ->

  toggle_record_macro_vim: ->
    if AtomKeyboardMacros.keyCaptured
      AtomKeyboardMacros.end_kbd_macro()
      AtomKeyboardMacros.name_last_kbd_macro_with_string(@name)
      commands = AtomKeyboardMacros.macroCommands
      @mode = InputMode.None
      window.removeEventListener('keydown', @eventListener, true)
    else
      @mode = InputMode.Record
      @waitInput()

  execute_macro_vim: ->
    @mode = InputMode.Execute
    @waitInput()

  waitInput: ->
    editor = atom.views.getView(atom.workspace.getActiveTextEditor())
    @model = new HiddenInputViewModel(this, editor)

  input: (str) ->
    editor = atom.views.getView(atom.workspace.getActiveTextEditor())
    editor.focus()
    return unless str
    return if str.length <= 0

    switch @mode
      when InputMode.Record
        @startRecord(str)
      when InputMode.Execute
        @startExecute(str)

  # @eventListener
  keyboardEventHandler: (e) ->
    # check editor parentNode for find 'vim-hidden-normal-mode-input'
    editorElement = e.target?.parentNode
    className = editorElement?.className
    if className?.indexOf('vim-hidden-normal-mode-input') >= 0
      #console.log('found vim-hidden-normal-mode-input', editorElement)
      return if e.ctrlKey or e.altKey or e.metaKey

      character = atom.keymaps.keystrokeForKeyboardEvent(e)
      #console.log('keystrokeForKeyboardEvent', character)

      obj = {
        fn: {
          execute: @singleExecute.bind(this)
          toString: @singleToString.bind(this)
          toSaveString: @singleToSaveString.bind(this)
          instansiateFromSavedString: @singleInstansiateFromSavedString.bind(this)
        }
        options: {
          character: character
        }
      }
      AtomKeyboardMacros.push_plugin_command obj
      #window.removeEventListener('keydown', @eventListener, true)
      return

    #console.log('check panels')
    # check bottom panel for find 'vim-normal-mode-input-element'
    panels = atom.workspace.getBottomPanels()
    inputPanel = null
    for panel in panels
      className = panel.className or panel.item.className
      if className.indexOf('normal-mode-input') == 0
        inputPanel = panel
        break

    unless inputPanel
      return

    @key_inputs.push e

    if e.keyIdentifier == 'Enter'
      item = inputPanel.getItem()
      text = item.childNodes?[0]?.getModel?()?.getText?()
      unless text
        return
      obj = {
        fn: {
          execute: @execute.bind(this)
          toString: @toString.bind(this)
          toSaveString: @toSaveString.bind(this)
          instansiateFromSavedString: @instansiateFromSavedString.bind(this)
        }
        options: {
          inputs: @key_inputs
          text: text
          enter: e
        }
      }
      AtomKeyboardMacros.push_plugin_command obj
      #window.removeEventListener('keydown', @eventListener, true)
    #else
      #if e.keyCode == 27
        #console.log('Escape')
        #window.removeEventListener('keydown', @eventListener, true)

  #
  #
  #
  execute: (options) ->
    panels = atom.workspace.getBottomPanels()
    inputPanel = null
    for panel in panels
      className = panel.className or panel.item.className
      if className.indexOf('normal-mode-input') == 0
        inputPanel = panel
        break
    unless inputPanel
      return

    text = options.text
    enter = options.enter
    return unless text and enter

    # search 'normal-mode-input'
    panels = atom.workspace.getBottomPanels()
    inputPanel = null
    for panel in panels
      className = panel.className or panel.item.className
      if className.indexOf('normal-mode-input') == 0
        inputPanel = panel
        break
    unless inputPanel
      return

    text = options.text
    states = @vim_module.vimStates
    states.forEach (state) ->
      stack = state.opStack
      history = state.history
      #console.log('history', history)
      #console.log('normalModeInputView', state.editor?.normalModeInputView?)
      if state.editor?.normalModeInputView?
        #console.log('stack', stack)
        #console.log('state:', state)
        # search TextEditor
        #console.log('inputPanel', inputPanel)
        editorElement = inputPanel.item.editorElement
        editor = editorElement?.getModel?()
        #console.log('editor', editor)
        return unless editor
        editor.setText text
        inputPanel.show()
        #console.log('inputPanel', inputPanel)
        try
          inputPanel.item?.confirm?()
        catch error
          console.log(error)

  toString: (tabs) ->

  toSaveString: ->

  instansiateFromSavedString: (str) ->

  #
  # single character
  #
  singleExecute: (options) ->
    character = options.character
    editor = atom.workspace.getActiveTextEditor()
    view = atom.views.getView(editor)
    parentNode = view.parentNode
    elements = parentNode.getElementsByClassName('vim-hidden-normal-mode-input')
    return unless elements.length > 0
    item = elements[0]
    editorElement = item.editorElement
    #console.log('editorElement', editorElement)
    return unless editorElement

    model = editorElement.getModel?()
    #console.log('model', model)
    model.setText character

  singleToString: (tabs) ->

  singleToSaveString: ->

  singleInstansiateFromSavedString: (str) ->

  #
  #
  #
  startRecord: (@name) ->
    @baseEditor = atom.views.getView(atom.workspace.getActiveTextEditor())
    window.addEventListener('keydown', @eventListener, true)
    @key_inputs = []

    AtomKeyboardMacros.start_kbd_macro()

  startExecute: (name) ->
    #console.log('macro cmds', AtomKeyboardMacros.macroCommands)
    editor = atom.views.getView(atom.workspace.getActiveTextEditor())
    editor.focus()
    AtomKeyboardMacros.execute_named_macro_with_string(name)

class Input
  constructor: (@characters) ->
  isComplete: -> true
  isRecordable: -> true
