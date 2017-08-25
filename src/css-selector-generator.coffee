class CssSelectorGenerator

  default_options:
    # choose from 'tag', 'id', 'class', 'nthchild', 'attribute'
    selectors: ['id', 'class', 'tag', 'nthchild']
    combinationsLimit: 20

  constructor: (options = {}) ->
    @options = {}
    @setOptions @default_options
    @setOptions options

  setOptions: (options = {}) ->
    for key, val of options
      @options[key] = val if @default_options.hasOwnProperty key

  isElement: (element) ->
    !!(element?.nodeType is 1)

  getParents: (element) ->
    result = []
    if @isElement element
      current_element = element
      while @isElement current_element
        result.push current_element
        current_element = current_element.parentNode
    result

  getTagSelector: (element) ->
    @sanitizeItem element.tagName.toLowerCase()

  # escapes special characters in class and ID selectors
  sanitizeItem: (item) ->
    characters = (item.split '').map (character) ->
      # colon is valid character in an attribute, but has to be escaped before
      # being used in a selector, because it would clash with the CSS syntax
      if character is ':'
        "\\#{':'.charCodeAt(0).toString(16).toUpperCase()} "
      else if /[ !"#$%&'()*+,./;<=>?@\[\\\]^`{|}~]/.test character
        "\\#{character}"
      else
        escape character
          .replace /\%/g, '\\'

    return characters.join ''


  getIdSelector: (element) ->
    id = element.getAttribute 'id'

    # ID must... exist, not to be empty and not to contain whitespace
    if (
      # ...exist
      id? and
      # ...not be empty
      (id isnt '') and
      # ...not contain whitespace
      not (/\s/.exec id) and
      # ...not start with a number
      not (/^\d/.exec id)
    )
      sanitized_id = "##{@sanitizeItem id}"
      # ID must match single element
      if element.ownerDocument.querySelectorAll(sanitized_id).length is 1
        return sanitized_id

    null

  getClassSelectors: (element) ->
    result = []
    class_string = element.getAttribute 'class'
    if class_string?
      # remove multiple whitespaces
      class_string = class_string.replace /\s+/g, ' '
      # trim whitespace
      class_string = class_string.replace /^\s|\s$/g, ''
      if class_string isnt ''
        result = for item in class_string.split /\s+/
          ".#{@sanitizeItem item}"
    result

  getAttributeSelectors: (element) ->
    result = []
    blacklist = ['id', 'class']
    for attribute in element.attributes
      unless attribute.nodeName in blacklist
        result.push "[#{attribute.nodeName}=#{attribute.nodeValue}]"
    result

  getNthChildSelector: (element) ->
    parent_element = element.parentNode
    if parent_element?
      counter = 0
      siblings = parent_element.childNodes
      for sibling in siblings
        if @isElement sibling
          counter++
          return ":nth-child(#{counter})" if sibling is element
    null


  testSelector: (element, selector, inDocument) ->
    if selector? and selector isnt ''
      root = if inDocument then element.ownerDocument else element.parentNode
      found_elements = root.querySelectorAll selector
      return found_elements.length is 1 and found_elements[0] is element
    false


  # helper function that looks for the first unique combination
  testCombinations: (element, items, tag) ->
    test = (combinations) =>
      selector = combinations.join('')
      # if tag selector is enabled, try attaching it
      selector = tag + selector if tag?
      selector if @testSelector element, selector

    @filterCombinations items, test


  getUniqueSelector: (element) ->
    tag_selector = @getTagSelector element

    for selector_type in @options.selectors
      switch selector_type

        # ID selector (no need to check for uniqueness)
        when 'id'
          selector = @getIdSelector element

        # tag selector (should return unique for BODY)
        when 'tag'
          selector = tag_selector if tag_selector && @testSelector element, tag_selector

        # class selector
        when 'class'
          selectors = @getClassSelectors element
          if selectors? and selectors.length isnt 0
            selector = @testCombinations element, selectors, tag_selector

        # attribute selector
        when 'attribute'
          selectors = @getAttributeSelectors element
          if selectors? and selectors.length isnt 0
            selector = @testCombinations element, selectors, tag_selector

        # if anything else fails, return n-th child selector
        when 'nthchild'
          selector = @getNthChildSelector element

      return selector if selector

    return '*'


  getSelector: (element) ->
    selectors = []

    parents = @getParents element
    for item in parents
      selector = @getUniqueSelector item
      if selector?
        selectors.unshift selector
        result = selectors.join ' > '
        return result if @testSelector element, result, true

    return null


  filterCombinations: (items = [], test) ->
    # there are 2^items.length combinations, it returns the first matching
    advance = (indexes) ->
      for i in [indexes.length-1..0]
        maxValue = items.length - (indexes.length - i)
        if indexes[i] < maxValue  # is incrementable
          startIndex = i
          break
      return false if !startIndex?
      startValue = indexes[startIndex]
      for i in [startIndex..indexes.length-1]
        indexes[i] = ++startValue
      return true

    counter = 0
    length = 1  # array range for [1..0] would not be empty
    while length <= items.length
      indexes = [0..length-1]
      loop
        result = test(indexes.map (i) -> items[i])
        counter++
        return result if result || counter >= @options.combinationsLimit
        break if !advance(indexes)
      length++


if define?.amd
  define [], -> CssSelectorGenerator
else
  root = if exports? then exports else this
  root.CssSelectorGenerator = CssSelectorGenerator
