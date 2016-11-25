HiddenInputView = require './hidden-input-view'

module.exports =
class HiddenInputViewModel
  constructor: (@controller, @editor) ->
    @view = new HiddenInputView().initialize(this, atom.views.getView(@editor))
    @editor.normalModeInputView = @view
    #@controller.onDidFailToCompose => @view.remove()

  confirm: (view) ->
    value = @view.value
    delete @editor.normalModeInputView
    @controller.input(value)

  cancel: (view) ->
    delete @editor.normalModeInputView
    @controller.input('')
