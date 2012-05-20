#
#  slideview.coffee
#  ----------------
#

# jQuery or similar is required too, but you won't be using CommonJS for that will you?
_ = require "lib/underscore"
Backbone = require "lib/backbone"

# anonymous export - good or bad?
module.exports = class extends Backbone.View
  
  initialize: =>
    @el = $ @el
    @cache = {}
    @className = @className
    @slideClassName = "slide"
    @firstRun = true
    @index = 0
    @loaded = 0
    @timer = null
    @master = null
    @animating = false
    @queue = []
    
    # pass any of these in as an options to the constructor
    @firstTransition ?= false
    @dissolve ?= false
    @autoSize ?= true
    @resizeParent ?= true
    @cacheLimit ?= -1
    @slides ?= []
    @slaves ?= []
    @intervalDuration ?= 5000
    @transitionDuration ?= 650
  
  preload: =>
    @preloading = true
    @jump @index
      
  start: =>
    if not @running()
      @jump @index
      @timer = setInterval @next, @getIntervalDuration()

  stop: =>
    if @running()
      clearInterval @timer
      @timer = null

  running: =>
    return @timer?
  
  next: =>
    if @animating
      @queue.push @next
      return
    if ++@index == @slides.length
      @index = 0
    @changeSlide "next"
    
  back: =>
    if @animating
      @queue.push @back
      return
    if --@index < 0
      @index = @slides.length-1
    @changeSlide "back"
  
  jump: (index) =>
    if @animating
      @queue.push =>
        @jump index
      return
    if index > -1 && index <= @slides.length-1
      @index = index
      @changeSlide "jump", index
  
  
  # Methods below are private
  # -------------------------
  
  getIntervalDuration: =>
    return if @intervalDuration instanceof Array then @intervalDuration[@index] else @intervalDuration
  
  changeSlide: (action, args) =>
    # reset the interval in case buttons are being clicked manually
    if @running()
      clearInterval @timer
      @timer = setInterval @next, @getIntervalDuration()
    
    # clear load count and start loading
    @loaded = 0
    @load()
    
    # next / back any slaves and bind
    # to each one's onload event
    for slave in @slaves
      slave.master = @
      slave[action] args
  
  load: =>
    # remembmer the last slide
    @lastSlide = $ _.last @el.children()
    
    # check to see if we already have a DOM element for
    # this slide. if so, trigger onload event immediately
    @url = @slides[@index] #+ "?ckiller=" + (new Date).getTime()
    @currentSlide = @cache[@url]
    if @currentSlide?
      @onload()

    # if not, create it and use an img
    # DOM element to wait for it to load
    # even though we will be using css's
    # background-image properties for display
    else
      @currentSlide = $("<div>").addClass(@slideClassName).css
        "background-image"    : "url(" + @url + ")"
        "background-repeat"   : "no-repeat"
        "background-position" : "center"
        "background-size"     : "100%"
        "visibility"          : "hidden"
        "position"            : "absolute"
        "top"                 : "0px"
        "left"                : "0px"
      @el.prepend @currentSlide
      
      @loader = new Image
      $(@loader).load @onload # for ie
      @loader.onerror = () =>
        # if it failed, be sure to pull the div
        @currentSlide.remove()
      @loader.src = @url
  
  onload: (evt) =>
    # if the event was triggered by our internal @loader
    # be sure to cache the new @currentSlide
    if evt? and evt.type == "load" and @loader?
      @cache[@url] = @currentSlide.css
        "visibility": "hidden"
      
      # adjust dimensions?
      if @autoSize
        size =
          width: @loader.width
          height: @loader.height
        if @resizeParent
          @el.css size
          @currentSlide.css 
            width: "100%"
            height: "100%"
        else
          @currentSlide.css size
          
      # release the @loader and @url
      @loader = @url = null
    
    # check to see if everybody has what they need
    if ++@loaded == 1 + @slaves.length
      
      # if we are a slave, let the master know we are ready
      if @master?
        @master.onload()
      else
        # fire an onload event
        @trigger "onload", @
      
        # if we make it here and aren't preloading, then 
        # we are in charge of running the transitions
        if not @preloading
          slave.transition() for slave in @slaves
          @transition()
        else
          @preloading = null
  
  transition: =>
    duration = if @transitionDuration instanceof Array then @transitionDuration[@index] else @transitionDuration
    if @firstRun and not @firstTransition
      duration = 0
      @currentSlide.css
        "opacity": 1
    else
      @currentSlide.css
        "opacity": 0
    @firstRun = false
    
    # if the slides are the same, just make 
    # sure everything is visible and bail
    if @lastSlide[0] == @currentSlide[0]
      @currentSlide.css
        "visibility": "visible"
        "opacity"   : 1
      return
    
    # will change
    @animating = true
    @trigger "slidewillchange", @
    
    # make sure the new slide is visible and in front
    @el.append @currentSlide.css("visibility", "visible")
    
    # callback
    animationComplete = =>
      # hide the @lastSlide when we're done
      if @lastSlide.length
        @lastSlide.css
          "visibility": "hidden"
  
      # and make sure to run any ops in the queue
      @animating = false
      if @queue.length
        @queue.pop()()
  
      # did change event
      @trigger "slidedidchange", @
    
    # fade it in
    if duration
      @currentSlide.animate
        "opacity": 1.0,
          duration: duration
          complete: animationComplete
      
      # respect @dissolve by fading out @lastSlide
      if @lastSlide.length and @dissolve
        @lastSlide.animate
          "opacity": 0,
            duration: duration
            
    # or just be done with it
    else
      @currentSlide.css
        "opacity": 1
      animationComplete()
