Ember.Widgets.TextEditorComponent = Ember.Component.extend
  templateName: 'text_editor'
  selectedFontName: 'Helvetica Neue'
  selectedFontSize: '2'
  selectedForeColor: 'rgb(0, 0, 0)'
  isToolbarVisible: true

  EDITOR_CLASS: 'text-editor'

  commands: [
    'bold',
    'italic',
    'underline',
    'fontName',
    'fontSize',
    'foreColor',
    'indent',
    'outdent'
    'insertOrderedList',
    'insertUnorderedList',
    'justifyLeft',
    'justifyCenter',
    'justifyRight',
    'strikeThrough',
  ]

  fontNames: [
    'Arial',
    'Calibri',
    'Cambria',
    'Consolas',
    'Corsiva',
    'Courier New',
    'Georgia',
    'Helvetica Neue',
    'Helvetica',
    'Sans-Serif',
    'Serif',
    'Syncopate',
    'Times New Roman',
    'Trebuchet MS',
    'Verdana'
  ]

  fontSizes: [
    {size:'1', name: '8'},
    {size:'2', name: '10'},
    {size:'3', name: '12'},
    {size:'4', name: '14'},
    {size:'5', name: '18'},
    {size:'6', name: '24'},
    {size:'7', name: '36'}
  ]
  iframeHeadContents: """
    <style>
      body {
        margin: 0;
      }
      .text-editor {
        min-height: 100%;
        -webkit-box-sizing: border-box;
        -moz-box-sizing: border-box;
        box-sizing: border-box;
        padding: 10px 10px 0 10px;
        font-family: "Helvetica Neue";
      }
      .text-editor:focus {
        outline: none;
      }
      .non-editable {
        display: inline-block;
        background-color: #ccc;
        padding: 0 5px;
        border-radius: 3px;
        list-style-type: none;
        cursor: pointer;
      }
    </style>
    """
  iframeBodyContents: """<div class="text-editor" contenteditable="true"></div>"""

  fontChooserItemViewClass: Ember.Widgets.SelectOptionView.extend
    templateName: 'font_chooser_item'
    style: Ember.computed ->
      "font-family:#{@get('label')};"
    .property 'label'

  getEditor: ->
    @$('iframe.text-editor-frame').contents().find('.text-editor')

  getDocument: ->
    iframe = @$('iframe.text-editor-frame')[0]
    iframe.contentDocument || iframe.contentWindow.document

  # Returns true if the entire range is in the text editor
  inEditor: (range) ->
    @$(range.endContainer).parents().has(range.startContainer).first().closest('.' + @EDITOR_CLASS).length > 0

  isTargetInEditor: (event) ->
    not Ember.isEmpty($(event.target).closest('.' + @EDITOR_CLASS))

  # Return the last child node of the editor
  getOrCreateLastElementInEditor: ->
    editor = @getEditor()[0]
    unless editor.childElementCount > 0
      # Insert div in text editor if none exists
      @insertHTMLAtRange(@selectElement(editor), "<div>&nbsp;</div>")
    return editor.children[editor.children.length - 1]

  onSelectedFontNameDidChange: Ember.observer ->
    @fontName @get('selectedFontName')
  , 'selectedFontName'

  onSelectedFontSizeDidChange: Ember.observer ->
    @fontSize @get('selectedFontSize')
  , 'selectedFontSize'

  onSelectedForeColorDidChange: Ember.observer ->
    @foreColor @get('selectedForeColor')
  , 'selectedForeColor'

  init: ->
    @_super()

    # Defines commands in @get('commands'), such as fontName and fontSize
    @get('commands').forEach (command) =>
      @set command, (arg) ->
        @getDocument().execCommand command, true, arg

  didInsertElement: ->
    @_super()
    iframe = @$('iframe.text-editor-frame').contents()
    iframe.find('body').append(@iframeBodyContents)
    iframe.find('head').append(@iframeHeadContents)
    @getDocument().execCommand 'styleWithCSS', true, true

    iframe = @$('iframe.text-editor-frame')[0]
    iframe.contentWindow.onkeyup = (event) =>
      @keyUp(event)
    iframe.contentWindow.onkeydown = (event) =>
      @keyDown(event)
    iframe.contentWindow.onmouseup = (event) =>
      @mouseUp(event)
    iframe.contentWindow.onmousedown = (event) =>
      @mouseDown(event)
    iframe.contentWindow.onclick = (event) =>
      @click(event)

  keyUp: (event) ->
    @queryCommandState()

  mouseUp: (event) ->
    @queryCommandState()

  queryCommandState: ->
    idocument = @getDocument()
    @set 'isBold',     idocument.queryCommandState('bold')
    @set 'isItalic',   idocument.queryCommandState('italic')
    @set 'isUnderline',idocument.queryCommandState('underline')

    @set 'isJustifyLeft', idocument.queryCommandState('justifyLeft')
    @set 'isJustifyCenter',   idocument.queryCommandState('justifyCenter')
    @set 'isJustifyRight',idocument.queryCommandState('justifyRight')

    # Font names with spaces need to have the start and end quotes removed
    @set 'selectedFontName', idocument.queryCommandValue('fontName').replace(/^'/, '').replace(/'$/, '')
    @set 'selectedFontSize', idocument.queryCommandValue('fontSize')
    @set 'selectedForeColor', idocument.queryCommandValue('foreColor')

Ember.Widgets.DomHelper = Ember.Mixin.create
  KEY_CODES: {
    BACKSPACE: 8,
    DELETE: 46,
    DOWN: 40,
    ENTER: 13,
    LEFT: 37,
    RIGHT: 39,
    SPACEBAR: 32,
    TAB: 9,
    UP: 38
  }

  # Set the selected range to the given element, with the option to collapse the selection to the
  # beginning or end
  #   element       the element to select
  #   collapseMode  "none", "beginning", "end"
  selectElement: (element, collapseMode="end") ->
    # http://stackoverflow.com/questions/1125292/how-to-move-cursor-to-end-of-contenteditable-entity
    if(document.createRange)  # Firefox, Chrome, Opera, Safari, IE 9+
      range = document.createRange()
      # Select the entire contents of the element with the range
      range.selectNodeContents(element)
      if collapseMode != "none"
        # collapse the range to the end point. false means collapse to end rather than the start
        range.collapse(if collapseMode == "beginning" then true else false)
      selection = window.getSelection()
      selection.removeAllRanges()
      selection.addRange(range)
      return range

  # Wrapper around range.deleteContents that also deletes empty containers in the range
  deleteRange: (range) ->
    startParent = range.startContainer.parentNode
    endParent = range.endContainer.parentNode
    range.deleteContents()
    if @isEmpty(startParent)
      $(startParent).remove()
    if @isEmpty(endParent)
      $(endParent).remove()

  # Converts html string to node then inserts at range
  insertHTMLAtRange: (range, html) ->
    @insertElementAtRange(range, @createElementsFromString(html)[0])

  # Inserts node at range
  insertElementAtRange: (range, node) ->
    @deleteRange(range)
    range.insertNode(node)
    node

  getCurrentRange: ->
    iframe = @$('iframe.text-editor-frame')[0]
    idocument = iframe.contentDocument || iframe.contentWindow.document
    if idocument.getSelection().rangeCount > 0 then idocument.getSelection().getRangeAt(0) else null

  # Returns true if the element has no child elements and has either 0 child nodes or one child
  # node with nothing in it. Different from jQuery's .is(':empty'), which thinks some empty nodes
  # are not empty
  isEmpty: (element) ->
    return element.children.length == 0 &&
           element.childNodes.length <= 1 &&
           element.childNodes[0]?.length == 0

  createElementsFromString: (string) ->
    $("<div/>").html(string).contents()

  # get the node that is beside the current range on either the left or the right. Empty nodes,
  # or nodes containing only whitespace are ignored
  getNonEmptySideNode: (range, left=true, deep) ->
    nodeIsEmpty = (node) ->
      return node?.nodeValue?.trim().length == 0
    node = range[if left then 'startContainer' else 'endContainer']
    while ((sideNode = node[if left then 'previousSibling' else 'nextSibling']) is null or
    nodeIsEmpty(sideNode)) and !$(node).hasClass(@EDITOR_CLASS)  # not the editor div
      if nodeIsEmpty(sideNode)
        # Ignore this sideNode because it's empty. Go to the next/previous sibling
        node = node[if left then 'previousSibling' else 'nextSibling']
      else
        # Go to the parent because this node doesn't have a side node
        node = node.parentNode
    if deep
      # Deep means go to the deepest element node
      while sideNode?.children?.length > 0
        index = if left then sideNode.children.length - 1 else 0
        sideNode = sideNode.children[index]
    return sideNode

# Base class for NonEditablePill that can be inserted into the TextEditorWithNonEditableComponent
Ember.Widgets.BaseNonEditablePill = Ember.Controller.extend Ember.Widgets.DomHelper,

  textEditor: null
  params: Ember.computed -> {}

  ##############################################################################
  # Interface
  ##############################################################################

  name: null

  # Returns a string that is displayed to the user in the non-editable pill in the text editor.
  # This method is called whenever the text editor view is refreshed. Needs to be overriden.
  result: -> Ember.K

  # Configure the parameters of the pill, e.g. by displaying a modal with input options that are
  # then stored in @get('params')
  configure: ->
    @send 'modalConfirm'  # No configuration by default

  ##############################################################################

  actions:
    modalConfirm: ->
      @get('params')['pillId'] = @textEditor.getNewPillId()
      @get('params')['type'] = "" + @constructor
      @get('textEditor').insertPill this
    modalCancel: -> Ember.K

  # Update the text of the pill with the latest results
  updateContent: ->
    $(@get('pillElement')).text(@result())

  # Create a span element containing the correct text and with class=non-editable, that will then
  # be inserted into the text editor DOM.
  render: ->
    span = @createElementsFromString("<span></span>")
    span.addClass('non-editable')
    span.attr('title': @get('name'))
    # include all params as data-attributes
    for key, value of @get('params')
      span.attr('data-' + key.dasherize(), value)
    @set 'pillElement', span
    @updateContent(span)
    return span[0]

Ember.Widgets.NonEditableTextPill = Ember.Widgets.BaseNonEditablePill.extend
  name: "Custom Text"
  text: Ember.computed.alias 'params.text'

  result: ->
    @get('params.text')

  configure: ->
    modal = Ember.Widgets.ModalComponent.popup
      content: this
      targetObject: this
      confirm: "modalConfirm"
      cancel: "modalCancel"
      contentViewClass: Ember.View.extend
        templateName: 'non_editable_text_pill_configuration'
      headerText: @get('name')
      confirmText: "Insert"

Ember.Widgets.TodaysDate = Ember.Widgets.BaseNonEditablePill.extend
  name: "Today's Date"

  result: -> Date()

Ember.Widgets.TextEditorWithNonEditableComponent =
Ember.Widgets.TextEditorComponent.extend Ember.Widgets.DomHelper,
  pillId:           0
  INVISIBLE_CHAR:   '\uFEFF'
  mouseDownTarget:  null

  pillOptions: [Ember.Widgets.TodaysDate, Ember.Widgets.NonEditableTextPill]

  _pillOptions : Ember.computed ->
    @getWithDefault('pillOptions', []).map (option) =>
      option.create textEditor: this
  .property('pillOptions')

  selectedPillOption: null

  selectedPillOptionDidChange: Ember.observer ->
    selectedPillOption = @get('selectedPillOption')
    return unless selectedPillOption
    selectedPillOption.configure()
    @set 'selectedPillOption', null
  , 'selectedPillOption'

  serialize: ->
    raw_html = @getEditor().html()
    div = $('<div/>').html(raw_html)
    $('.non-editable-caret', div).remove()
    $('.non-editable', div).empty()
    return div.html()

  updateNonEditablePillContent: ->
    pillElements = @getEditor().find('.non-editable[data-pill-id]')
    for pillElement in pillElements
      # Deserialize the pillElement into a pill object
      data = $(pillElement).data()
      return unless data.type
      params = {}
      for key, value of data
        params[key] = value
      pill = Ember.get(data.type).create({'textEditor': this, 'params': params})

      $(pillElement).text(pill.result())

  getCurrentCaretContainer: (range) ->
    return $(range?.startContainer.parentElement).closest('.non-editable-caret')

  getNewPillId: ->
    @incrementProperty 'pillId'

  insertPill: (pill) ->
    # Ensure that we insert the factor in the text editor (move the range inside the editor if
    # not already)
    range = @getCurrentRange()
    if not range or not @inEditor(range)
      if not (range = @getCurrentRange()) or not @inEditor(range)
        @selectElement(@getOrCreateLastElementInEditor())
      range = @getCurrentRange()

    factor = @insertElementAtRange(range, pill.render())
    caretContainer = @insertCaretContainer(factor, false)

    # Set cursor to the end of the caret container just created
    @selectElement(caretContainer)
    # Remove other caret containers, excluding the one we just selected
    @removeCaretContainers()
    # select the caret container again (which has probably been moved)
    @selectElement(factor.nextSibling)

  isNonEditable: (node) ->
    not Ember.isEmpty($(node).closest('.non-editable'))

  # Get the non editable node, if any, to the left of the current range
  # Node: https://developer.mozilla.org/en-US/docs/Web/API/Node
  # Range: https://developer.mozilla.org/en-US/docs/Web/API/range
  getNonEditableOnLeft: (deep=false) ->
    return unless (currentRange = @getCurrentRange()) and leftNode = @getNonEmptySideNode(currentRange, true, deep)

    if currentRange.startOffset == 0 && @isNonEditable(leftNode)
      return leftNode
    else if currentRange.startOffset == 1 && @isNonEditable(leftNode) and
    currentRange.startContainer.nodeValue?.charAt(0) == @INVISIBLE_CHAR
      # i.e. we are in a non-editable caret container
      return leftNode

  # Get the non editable node, if any, to the right of the current range
  # Node: https://developer.mozilla.org/en-US/docs/Web/API/Node
  # Range: https://developer.mozilla.org/en-US/docs/Web/API/range
  getNonEditableOnRight: (deep=false) ->
    return unless (currentRange = @getCurrentRange()) and rightNode = @getNonEmptySideNode(currentRange, false, deep)

    endContainer = currentRange.endContainer
    if currentRange.endOffset == endContainer.length && @isNonEditable(rightNode)
      return rightNode
    else if currentRange.endOffset == endContainer.length - 1 and
    endContainer.nodeValue.charAt(endContainer.nodeValue.length - 1) == @INVISIBLE_CHAR and
    @isNonEditable(rightNode)
      return rightNode

  isRangeWithinNonEditable: (range) ->
    $startNode = $(range.startContainer.parentNode)
    $endNode = $(range.endContainer.parentNode)
    $startNode.hasClass('non-editable') && $endNode.hasClass('non-editable') && $startNode[0] == $endNode[0]

  getNonEditableParent: (node) ->
    while node
      if $(node).hasClass('non-editable')
        return node
      node = node.parentElement

  # Inserts a "caret container" next to the target node
  # Used to allow users to type next to a non-editable element (i.e. the non editable pill).
  # Otherwise when the user tries to type text preceding or following a non-editable element, the
  # text will appear in the non-editable element. The caret container gives us a place to
  # temporarily put the cursor.
  insertCaretContainer: (target, before) ->
    caretContainer = @createElementsFromString('<span class="non-editable-caret">' + @INVISIBLE_CHAR + '</span>')[0]
    if (before)
      $(caretContainer).insertBefore(target)
    else
      $(caretContainer).insertAfter(target)
    return caretContainer

  removeCaretContainer: (caretContainer) ->
    if (child = caretContainer.childNodes[0]) && child.nodeValue.charAt(0) == @INVISIBLE_CHAR
      child = child.deleteData(0, 1)
    savedSelection = rangy.saveSelection(@$('iframe.text-editor-frame')[0].contentWindow)
    contents = $(caretContainer).contents()
    $(caretContainer).replaceWith(contents)
    rangy.restoreSelection(savedSelection)

  removeCaretContainers: ->
    range = @getCurrentRange()
    currentCaretContainer = @getCurrentCaretContainer(range)
    while (caretContainer = @getEditor().find('.non-editable-caret').not(currentCaretContainer)[0])
      child = caretContainer.childNodes[0]
      if child && child.nodeValue?.charAt(0) == @INVISIBLE_CHAR
        child = child.deleteData(0, 1)
      # via http://stackoverflow.com/questions/170004/how-to-remove-only-the-parent-element-and-not-its-child-elements-in-javascript
      contents = $(caretContainer).contents()
      $(caretContainer).replaceWith(contents)
      caretContainer.childNodes[caretContainer.childNodes.length-1]

  moveSelection: ->
    hasSideContent = (range, element, left) ->
      container = range.startContainer
      offset = range.startOffset

      if container.nodeType == 3  # i.e. TEXT_NODE (see https://developer.mozilla.org/en-US/docs/Web/API/Node.nodeType)
        len = container.nodeValue.length
        if (offset > 0 && offset < len) || (if left then offset == len else offset == 0)
          return
      return element

    @removeCaretContainers()
    return unless currentRange = @getCurrentRange()

    isCollapsed = currentRange.collapsed
    nonEditableStart = @getNonEditableParent(currentRange.startContainer)
    nonEditableEnd = @getNonEditableParent(currentRange.endContainer)
    parentCaret = @getCurrentCaretContainer(currentRange)

    if nonEditableStart || nonEditableEnd
      if currentRange.collapsed
        if (element = hasSideContent(currentRange, nonEditableStart || nonEditableEnd, true))
          caretContainer = @insertCaretContainer(element, true)
        else if (element = hasSideContent(currentRange, nonEditableStart || nonEditableEnd, false))
          caretContainer = @insertCaretContainer(element, false)

        if caretContainer
          # place cursor at end of caret unless the caret is the first child
          collapse = if $(caretContainer).is(":first-child") then "beginning" else "end"
          @selectElement(caretContainer, collapse)
          return

      # We are in the middle of a non editable (either collapsed or not). Select the entire non-
      # editable if part is selected. This includes the case where multiple non-editables and
      # parts are selected.
      if nonEditableStart
        currentRange.setStartBefore(nonEditableStart)
      if nonEditableEnd
        currentRange.setEndAfter(nonEditableEnd)
      selection = window.getSelection()
      selection.removeAllRanges()
      selection.addRange(currentRange)
    else if parentCaret?.length > 0 and !@isNonEditable(@getNonEmptySideNode(currentRange, true)) and
    !@isNonEditable(@getNonEmptySideNode(currentRange, false))
        @removeCaretContainer(parentCaret[0])

  keyDown: (event) ->
    return unless @isTargetInEditor(event)

    handleLeftNodeCase = =>
      if leftNode
        if keyCode == @KEY_CODES.LEFT and isCollapsed
          @selectElement(leftNode, "none")
          event.preventDefault()
        else if keyCode == @KEY_CODES.BACKSPACE
          @selectElement(leftNode, "none")
      else if leftNodeDeep and keyCode == @KEY_CODES.BACKSPACE
        # This happens when the last node on the previous line is a non-editable
        @insertCaretContainer(leftNodeDeep, false)

    handleRightNodeCase = =>
      if rightNode
        if keyCode == @KEY_CODES.DELETE
          @selectElement(rightNode, "none")
        else if keyCode == @KEY_CODES.RIGHT and isCollapsed
          @selectElement(rightNode, "none")
          event.preventDefault()
      else if rightNodeDeep and keyCode == @KEY_CODES.DELETE and not rightNode
        # This happens when the first node on the next line is a non-editable
        @insertCaretContainer(rightNodeDeep, true)

    isCharacter = (keyCode) ->
      return keyCode >= 48 && keyCode <= 90 or   # [0-9a-z]
             keyCode >= 96 && keyCode <= 111 or  # num pad characters
             keyCode >= 186 && keyCode <= 222    # punctuation

    keyCode = event.keyCode
    @moveSelection()
    range = @getCurrentRange()
    isCollapsed = range.collapsed

    startElement = range.startContainer
    endElement = range.endContainer
    nonEditableParent = @isNonEditable(startElement) || @isNonEditable(endElement)
    leftNode = @getNonEditableOnLeft()
    rightNode = @getNonEditableOnRight()
    leftNodeDeep = @getNonEditableOnLeft(true)
    rightNodeDeep = @getNonEditableOnRight(true)

    if (event.metaKey || event.ctrlKey) && keyCode not in [@KEY_CODES.DELETE, @KEY_CODES.BACKSPACE]
      return

    if isCharacter(keyCode) or keyCode == @KEY_CODES.BACKSPACE or keyCode == @KEY_CODES.DELETE
      if (leftNode || rightNode) and !isCollapsed
        caret = @insertCaretContainer(leftNode || rightNode, if leftNode then false else true)
        @deleteRange(range)
        @selectElement(caret)
      else if nonEditableParent
        @deleteRange(range)  # special delete in case a non-editable is selected

      if (keyCode == @KEY_CODES.BACKSPACE || keyCode == @KEY_CODES.DELETE) && !isCollapsed && nonEditableParent
        # We already performed the delete action
        return event.preventDefault()

    handleLeftNodeCase()
    handleRightNodeCase()

  keyUp: (event) ->
    return unless @isTargetInEditor(event)
    @moveSelection()
    @_super()

  mouseDown: (event) ->
    return unless @isTargetInEditor(event)
    @mouseDownTarget = event.target  # Save mousedown target for use in mouseup handler
    @moveSelection()

  mouseUp: (event) ->
    return unless @isTargetInEditor(event)
    @moveSelection()  # expand selection if only part of a non-editable was selected
    currentRange = @getCurrentRange()
    if @isNonEditable(event.target) and event.target == @mouseDownTarget and @isRangeWithinNonEditable(currentRange)
      # This prevents the user from putting the cursor within a non-editable that was previously selected
      @selectElement(event.target, "none")
      event.preventDefault()
    @_super()

  click: (event) -> Ember.K