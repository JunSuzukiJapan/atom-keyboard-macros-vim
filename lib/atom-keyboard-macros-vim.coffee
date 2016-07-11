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
        if str.length == 1
          str = str.toLowerCase()
        @startExecute(str)

  # @eventListener
  keyboardEventHandler: (e) ->
    # check editor parentNode for find 'vim-hidden-normal-mode-input'
    editorElement = e.target?.parentNode
    className = editorElement?.className
    if className?.indexOf('vim-hidden-normal-mode-input') >= 0
      return if e.ctrlKey or e.altKey or e.metaKey

      character = atom.keymaps.keystrokeForKeyboardEvent(e)
      if character.indexOf('shift') == 0
        return

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
      return

    # check bottom panel for find 'vim-normal-mode-input-element'
    panels = atom.workspace.getBottomPanels()
    inputPanel = null
    for panel in panels
      className = panel.className or panel.item.className
      if className and className.indexOf('normal-mode-input') == 0
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
          text: text
        }
      }
      AtomKeyboardMacros.push_plugin_command obj

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
    return unless text

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

    states = @vim_module.vimStates
    states.forEach (state) ->
      stack = state.opStack
      history = state.history
      if state.editor?.normalModeInputView?
        # search TextEditor
        editorElement = inputPanel.item.editorElement
        editor = editorElement?.getModel?()
        return unless editor
        editor.setText text
        inputPanel.show()
        try
          inputPanel.item?.confirm?()
        catch error
          console.log(error)

  toString: (tabs) ->

  toSaveString: (options) ->
    '*P:atom-keyboard-macros-vim:instansiateFromSavedString:' + options.text + "\n"

  instansiateFromSavedString: (optionsText) ->
    fns = {
      execute: @execute.bind(this)
      toString: @toString.bind(this)
      toSaveString: @toSaveString.bind(this)
      instansiateFromSavedString: @instansiateFromSavedString.bind(this)
    }
    opts = {
      text: optionsText
    }
    new AtomKeyboardMacros.PluginCommand(fns, opts)

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
    return unless editorElement

    model = editorElement.getModel?()
    model.setText character

  singleToString: (tabs) ->

  singleToSaveString: (options) ->
    '*P:atom-keyboard-macros-vim:singleInstansiateFromSavedString:' + options.character + "\n"

  singleInstansiateFromSavedString: (optionsText) ->
    fns = {
      execute: @singleExecute.bind(this)
      toString: @singleToString.bind(this)
      toSaveString: @singleToSaveString.bind(this)
      instansiateFromSavedString: @singleInstansiateFromSavedString.bind(this)
    }
    opts = {
      character: optionsText
    }
    new AtomKeyboardMacros.PluginCommand(fns, opts)

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
    #console.log('vim_module', @vim_module)
    editor = atom.views.getView(atom.workspace.getActiveTextEditor())
    editor.focus()
    if name == "@"
      AtomKeyboardMacros.call_last_kbd_macro()
    else
      AtomKeyboardMacros.execute_named_macro_with_string(name)

class Input
  constructor: (@characters) ->
  isComplete: -> true
  isRecordable: -> true
