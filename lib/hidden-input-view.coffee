class HiddenInputView extends HTMLDivElement
  createdCallback: ->
    @className = "hidden-input-view"

  initialize: (@viewModel, @mainEditorElement) ->
    @editorElement = document.createElement "atom-text-editor"
    @editorElement.classList.add('editor')
    @editorElement.getModel().setMini(true)
    @editorElement.setAttribute('mini', '')
    @appendChild(@editorElement)

    @singleChar = true
    @defaultText = ''

    @classList.add('vim-hidden-normal-mode-input')
    @mainEditorElement.parentNode.appendChild(this)

    @focus()
    @handleEvents()

    this

  handleEvents: ->
    compositing = false
    @editorElement.getModel().getBuffer().onDidChange (e) =>
      @confirm() if e.newText and not compositing
    @editorElement.addEventListener 'compositionstart', -> compositing = true
    @editorElement.addEventListener 'compositionend', -> compositing = false

    atom.commands.add(@editorElement, 'core:confirm', @confirm.bind(this))
    atom.commands.add(@editorElement, 'core:cancel', @cancel.bind(this))
    atom.commands.add(@editorElement, 'blur', @cancel.bind(this))

  confirm: ->
    @value = @editorElement.getModel().getText() or @defaultText
    @viewModel.confirm(this)
    @removePanel()

  focus: ->
    @editorElement.focus()

  cancel: (e) ->
    @viewModel.cancel(this)
    @removePanel()

  removePanel: ->
    atom.workspace.getActivePane().activate()
    if @panel?
      @panel.destroy()
    else
      this.remove()

module.exports =
document.registerElement("hidden-input-view"
  extends: "div",
  prototype: HiddenInputView.prototype
)
