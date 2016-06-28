DEBUG = false
SPEED = 160
GRAVITY = 1100
FLAP = 320
SPAWN_RATE = 1 / 1200
OPENING = 100
SCALE = 1

MAXLB = 6
HEIGHT = 384
# WIDTH = 288
WIDTH = 500
# HEIGHT = 576
# WIDTH = 1024*2
# GAME_HEIGHT = 336
GROUND_HEIGHT = 64
GROUND_Y = HEIGHT - GROUND_HEIGHT

parent = document.querySelector("#screen")
gameStarted = undefined
gameOver = undefined

deadTubeTops = []
deadTubeBottoms = []
deadInvs = []

# dummy leaderboard
lb = [

    name: 'Arpit'
    score: '58'
    hall: 'AZ'
  ,
    name: 'Apoorv'
    score: '2'
    hall: 'NH'
  ,
  #   name: 'Soumyadeep'
  #   score: '10'
  #   hall: 'RP'
  # , 
  #   name: 'Vivek'
  #   score: '5'
  #   hall: 'RP'
  # , 
    name: 'Vikrant'
    score: '1'
    hall: 'RP'
  , 
    name: 'Arkanath'
    score: '100'
    hall: 'MS'
]
hallList = ['AZ', 'MT', 'RP', 'SN', 'NH', 'PT', 'RK', 'LLR', 'MS', 'LBS', 'MMM', 'HJB']
chosenHall = null
hallChosen = false
bg = null
# credits = null
tubes = null
invs = null
bird = null
ground = null
hall = null
gameOverPanel = null
lbPanel = null
gameOverGroup = null

secretKey = null
playerName = null
score = null
scoreText = null
instText = null
gameOverText = null
tryAgainText = null
gameOverScoreTxt1 = null
gameOverScoreTxt2 = null

playerNameInput = null

flapSnd = null
scoreSnd = null
hurtSnd = null
fallSnd = null
swooshSnd = null
hoverSnd = null
clickSnd = null

tubesTimer = null
spaceKey = null
numHalls = 12
buttonList = null
leaderboardButton = null
githubHtml = """<iframe src="http://ghbtns.com/github-btn.html?user=hyspace&repo=flappy&type=watch&count=true&size=large"
  allowtransparency="true" frameborder="0" scrolling="0" width="150" height="30"></iframe>"""

floor = Math.floor

main = ->
  randomString = (length, chars) ->
    result = '';
    for i in [length..1]
      result += chars[Math.floor(Math.random() * chars.length)];
    return result;
  
  spawntube = (openPos, flipped) ->
    tube = null

    tubeKey = if flipped then "tubeTop" else "tubeBottom"
    if flipped
      tubeY = floor(openPos - OPENING / 2 - 320)
    else
      tubeY = floor(openPos + OPENING / 2)

    if deadTubeTops.length > 0 and tubeKey == "tubeTop"
      tube = deadTubeTops.pop().revive()
      tube.reset(game.world.width, tubeY)
    else if deadTubeBottoms.length > 0 and tubeKey == "tubeBottom"
      tube = deadTubeBottoms.pop().revive()
      tube.reset(game.world.width, tubeY)
    else
      tube = tubes.create(game.world.width, tubeY, tubeKey)
      game.physics.arcade.enableBody(tube)
      tube.body.allowGravity = false

    # Move to the left
    tube.body.velocity.x = -SPEED
    tube

  spawntubes = ->
    # check dead tubes
    tubes.forEachAlive (tube) ->
      if tube.x + tube.width < game.world.bounds.left
        deadTubeTops.push tube.kill() if tube.key == "tubeTop"
        deadTubeBottoms.push tube.kill() if tube.key == "tubeBottom"
      return
    invs.forEachAlive (invs) ->
      deadInvs.push invs.kill() if invs.x + invs.width < game.world.bounds.left
      return

    tubeY = game.world.height / 2 + (Math.random()-0.5) * game.world.height * 0.2

    # Bottom tube
    bottube = spawntube(tubeY)

    # Top tube (flipped)
    toptube = spawntube(tubeY, true)

    # Add invisible thingy
    if deadInvs.length > 0
      inv = deadInvs.pop().revive().reset(toptube.x + toptube.width / 2, 0)
    else
      inv = invs.create(toptube.x + toptube.width / 2, 0)
      game.physics.arcade.enableBody(inv)
      inv.width = 2
      inv.height = game.world.height
      inv.body.allowGravity = false
    inv.body.velocity.x = -SPEED
    return

  addScore = (_, inv) ->
    invs.remove inv
    score += 1
    scoreText.setText score
    scoreSnd.play()
    return

  sanitizeLB = ->
    lb.sort( (a, b) ->
      return parseInt(a.score) < parseInt(b.score)
    )
    while lb.length < MAXLB
      # add dummy 
      lb.push 
        name: '---'
        score: '-1'
        hall: 'DUMMY2'
    lb

  sendScore = ->
    # send all the scores..
    data = 
      score: score,
      name: playerName,
      hall: hallList[chosenHall],
      key: secretKey

    $.ajax
      type: 'POST',
      data: data,
      dataType: 'text'
      url: '/sendScore'
      success: (resp)-> 
        console.log(resp);
      ,
      error: ->
        console.log('error sending score!')      

  showLeaderBoard = ->
    playerName = playerNameInput.value
    sendScoreReq = sendScore()
    # move the game over panel first
    leaderboardButton.input.enabled = false
    if gameOverPanel.alive
      tween = game.add.tween(gameOverPanel).to(y:game.world.height * 1.5, 800, Phaser.Easing.Back.In, true);
      swooshSnd.play()
      # remove events heere as well, jsut to remove weird sounds. doesn't affect gameplay
      spaceKey.onDown.removeAll()
      bg.events.onInputDown.removeAll()
      tween.onComplete.add ->
        gameOverPanel.kill()
        lbPanel.revive()
        lbPanel.bringToTop()
        # bring up the leaderboard
        tween = game.add.tween(lbPanel).to(y:game.world.height / 2, 800, Phaser.Easing.Back.Out,true);
        # display all the shit
        txtRank = ''
        txtName = ''
        txtScore = ''
        # display "Loading" while youre loading the leaderbaord
        lbPanel.children[1].setText "Loading.."
        lbPanel.children[2].setText ""
        lbPanel.children[0].setText ""
        for x in [3..lbPanel.children.length-1]
          lbPanel.children[x].kill()
        popLB = ->
          for i in [0..lb.length-1]
            # check if dummy
            if lb[i].score < 0
              txtRank += '\n-'
              txtName += '\n---'
              txtScore += '\n---'
              lbPanel.children[3+i].kill()
            else
              txtRank += '\n' + (i+1)
              txtName += '\n' + lb[i].name
              txtScore += '\n' + lb[i].score
              hallSprite = lbPanel.children[3+i]
              hallSprite.revive()
              hallSprite.frameName = lb[i].hall + '/2'
            # hallSprite.animations.stop()
            # hallSprite.animations.destroy()
            # hallSprite.animations.add('fly', Phaser.Animation.generateFrameNames(hallList[lb[i].hall] + '/', 1, 3, '', 1), 10, true);
            # hallSprite.animations.play('fly')
              hallSprite.children[0].setText lb[i].hall
          lbPanel.children[0].setText txtRank
          lbPanel.children[1].setText txtName
          lbPanel.children[2].setText txtScore
        # shoudl wait till sendScoreReq is done, before asking for leaderboard.
        $.when(sendScoreReq).done (res) ->
          $.ajax 
            type: 'GET',
            url: '/getLeaderboard'
            success: (resp) -> 
              # good idea to sanitize the lb variable here.
              # lb = JSON.stringify(eval("(" + resp + ")"));
              lb = resp
              console.log('got lb = ' + lb)
              sanitizeLB()
              popLB()
            ,
            error: ->
              lb = []    
              sanitizeLB()
              popLB()
        

          # console.log 'setting text'
          # lbPanel.children[i].setText (i+1) + '\t\t\t\t' + lb[i].name + '\t\t\t\t\t' +lb[i].score
        # click/space to remove leaderBoard and go back to reset state:
        tween.onComplete.add ->
          fn = ->
            if lbPanel.alive
              tween = game.add.tween(lbPanel).to(y:game.world.height * 1.5, 800, Phaser.Easing.Back.In, true);
              swooshSnd.play()
              # remove events heere as well, jsut to remove weird sounds. doesn't affect gameplay
              spaceKey.onDown.removeAll()
              bg.events.onInputDown.removeAll()
              tween.onComplete.add ->
                lbPanel.kill()
                reset()
                # swooshSnd.play()
            else
              reset()
          bg.events.onInputDown.addOnce fn
          spaceKey.onDown.addOnce fn

  addHallSprite = (x, y, idx) ->
    # 0 indexed idx
    sprite = game.add.sprite x, y, 'sheet',   hallList[idx] + '/2'
    sprite.scale.setTo 2, 2
    sprite.smoothed = false
    sprite.anchor.setTo 0.5, 0.5
    # console.log('added btton at' + x + y)
    # sprTxt = game.add.text(0, 20, hallList[idx],
    #   font: "16px \"04b_19regular\""
    #   fill: "#fff"
    #   stroke: "#430"
    #   strokeThickness: 4
    #   align: "center"
    # )
    # sprTxt.anchor.setTo 0.5, 0.5
    # sprite.addChild sprTxt
    sprite
    
  setGameOver = ->
    gameOver = true
    bird.body.velocity.y = 100 if bird.body.velocity.y > 0
    bird.animations.stop()
    bird.frame = hallList[chosenHall] + '/2'
    # instText.setText "TOUCH\nTO TRY AGAIN"
    # instText.renderable = true
    hiscore = window.localStorage.getItem("hiscore")
    hiscore = (if hiscore then hiscore else score)
    hiscore = (if score > parseInt(hiscore, 10) then score else hiscore)
    window.localStorage.setItem "hiscore", hiscore
    # gameOverText.setText "GAMEOVER\n\nHIGH SCORE\n\n" + hiscore
    # gameOverText.renderable = true
    gameOverScoreTxt1.setText score
    gameOverScoreTxt2.setText hiscore

    # Stop all tubes
    tubes.forEachAlive (tube) ->
      tube.body.velocity.x = 0
      return

    invs.forEach (inv) ->
      inv.body.velocity.x = 0
      return

    # Stop spawning tubes
    game.time.events.remove(tubesTimer)

    # show game over panel
    
    game.time.events.add 1000, ->
      spaceKey.onDown.removeAll()
      bg.events.onInputDown.removeAll()
      gameOverPanel.revive()
      leaderboardButton.input.enabled = false
      game.world.bringToTop(gameOverGroup)
      # gameOverGroup.bringToTop(gameOverPanel)
      # gameOverPanel.bringToTop()
      tween = game.add.tween(gameOverPanel).to(y:game.world.height / 2, 800, Phaser.Easing.Back.Out,true);
      tween.onComplete.add ->
        leaderboardButton.input.enabled = true
        fn = ->
          playerName = playerNameInput.value
          sendScore()
          leaderboardButton.input.enabled = false
          if gameOverPanel.alive
            tween = game.add.tween(gameOverPanel).to(y:game.world.height * 1.5, 800, Phaser.Easing.Back.In, true);
            # console.log('setGameOver click cb called')
            swooshSnd.play()
            # remove events heere as well, jsut to remove weird sounds. doesn't affect gameplay
            spaceKey.onDown.removeAll()
            bg.events.onInputDown.removeAll()
            tween.onComplete.add ->
              gameOverPanel.kill()
              reset()
              # swooshSnd.play()
          else
            reset()
            # swooshSnd.play()
        bg.events.onInputDown.addOnce fn
        spaceKey.onDown.addOnce fn
      swooshSnd.play()

    # Make bird reset the game
    # game.time.events.add 1000, ->
      

    hurtSnd.play()
    return

  flap = ->
    start()  unless gameStarted
    unless gameOver
      # bird.body.velocity.y = -FLAP
      bird.body.gravity.y = 0;
      bird.body.velocity.y = -100;
      tween = game.add.tween(bird.body.velocity).to(y:-FLAP, 25, Phaser.Easing.Bounce.In,true);
      tween.onComplete.add ->
        bird.body.gravity.y = GRAVITY
      flapSnd.play()
    return

  preload = ->
    # for num in [1..numHalls]
    #   birdname = "bird" + num
    #   game.load.spritesheet birdname, "assets/birds/" + birdname + ".png", 36, 26
    #   btnname = "button" + num
    #   game.load.spritesheet btnname, "assets/buttons/" + btnname + ".png", 36, 26

    # game.load.bitmapFont('flappyfont', 'assets/fonts/flappyfont/flappyfont.png', 'assets/fonts/flappyfont/flappyfont.xml');
    # game.load.bitmapFont('flappyfont', 'assets/fonts/flappyfont/flappyfont.png', 'assets/fonts/flappyfont/flappyfont.fnt');
    # game.load.physics('birdphysics', 'assets/birds/bird.json');
    game.load.atlasJSONHash('sheet', 'assets/sheet.png', 'assets/sheet.json');
    assets =
      # physics:
        # birdphysics: ['assets/birds/bird.json']

      bitmapFont:
        flappyfont: ['assets/fonts/flappyfont/flappyfont.png', 'assets/fonts/flappyfont/flappyfont.fnt']

      spritesheet:
        # bird: [
        #   "assets/bird.png"
        #   36
        #   26
        # ]
        leaderboard: [
          "assets/leaderboard.png"
          52
          29
        ]

      image:
        tubeTop: ["assets/tube1.png"]
        tubeBottom: ["assets/tube2.png"]
        ground: ["assets/path.png"]
        bg: ["assets/bg2.png"]
        hall: ["assets/hall.png"]
        gameover: ["assets/gameover-panel.png"]
        lbPanel: ["assets/lbPanel.png"]

      audio:
        flap: ["assets/sfx_wing.mp3"]
        score: ["assets/sfx_point.mp3"]
        hurt: ["assets/sfx_hit.mp3"]
        fall: ["assets/sfx_die.mp3"]
        swoosh: ["assets/sfx_swooshing.mp3"]
        click: ["assets/keyboard_tap.mp3"]
        hover: ['assets/typewriter_key.mp3']

    Object.keys(assets).forEach (type) ->
      Object.keys(assets[type]).forEach (id) ->
        game.load[type].apply game.load, [id].concat(assets[type][id])
        return

      return

    return

  create = ->
    game.add.plugin(Fabrique.Plugins.InputField);

    # password = game.add.inputField(10, 90, {
    #   font: '18px Arial',
    #   fill: '#212121',
    #   fontWeight: 'bold',
    #   width: 150,
    #   padding: 8,
    #   borderWidth: 1,
    #   borderColor: '#000',
    #   borderRadius: 6,
    #   placeHolder: 'Password',
    #   type: Fabrique.InputType.password
    # });
    # enabling physics. don't know if necessary or not?
    game.physics.startSystem(Phaser.Physics.ARCADE);

    console.log("%chttps://github.com/hyspace/flappy", "color: black; font-size: x-large");
    ratio = window.innerWidth / window.innerHeight
    document.querySelector('#github').innerHTML = githubHtml if ratio > 1.15 or ratio < 0.7
    document.querySelector('#loading').style.display = 'none'

    # Set world dimensions
    game.scale.pageAlignVertically = true
    # game.scale.pageAlignHorizontally = true
    game.smoothed = false
    game.scale.scaleMode = Phaser.ScaleManager.SHOW_ALL
    game.scale.windowConstraints.bottom = "visual";
    game.scale.setGameSize(WIDTH, HEIGHT)

    # Draw bg
    bg = game.add.tileSprite(0, 0, WIDTH, HEIGHT, 'bg')
    # enable input. now put all global mouse events on bg.
    bg.inputEnabled = true;
    bg.input.priorityID = 0; # lower priority
    # dummy bird
    bird = game.add.sprite(0, 0)
    # Credits 'yo
    # credits = game.add.text(game.world.width / 2, HEIGHT - GROUND_Y + 50, "",
    #   font: "8px \"Press Start 2P\""
    #   fill: "#fff"
    #   stroke: "#430"
    #   strokeThickness: 4
    #   align: "center"
    # )
    # credits.anchor.x = 0.5


    # # Add clouds group
    # clouds = game.add.group()

    # Add tubes
    tubes = game.add.group()

    # Add invisible thingies
    invs = game.add.group()

    
    # add gameOverGroup
    gameOverGroup = game.add.group()
    # Add ground
    ground = game.add.tileSprite(0, GROUND_Y, WIDTH, GROUND_HEIGHT, "ground")
    ground.tileScale.setTo SCALE, SCALE

    # Add score text
    scoreText = game.add.text(game.world.width / 2, game.world.height / 4, "",
      font: "16px \"Press Start 2P\""
      fill: "#fff"
      stroke: "#430"
      strokeThickness: 4
      align: "center"
    )
    scoreText.anchor.setTo 0.5, 0.5

    # Add instructions text
    instText = game.add.text(game.world.width / 2, game.world.height - game.world.height / 4, "",
      font: "8px \"Press Start 2P\""
      fill: "#fff"
      stroke: "#430"
      strokeThickness: 4
      align: "center"
    )
    instText.anchor.setTo 0.5, 0.5

    # Add game over text
    gameOverText = game.add.text(game.world.width / 2, game.world.height / 2, "",
      font: "16px \"Press Start 2P\""
      fill: "#fff"
      stroke: "#430"
      strokeThickness: 4
      align: "center"
    )
    gameOverText.anchor.setTo 0.5, 0.5
    gameOverText.scale.setTo SCALE, SCALE
  
    # leaderboard panel
    lbPanel = game.add.sprite game.world.width / 2, game.world.height * 1.5, "lbPanel"
    lbPanel.anchor.setTo 0.5, 0.5
    lbPanel.kill()

    # add text fields to lbpanel. one field per column.
    txtRank = game.add.text -170, -10, "",
      font: "16px \"Press Start 2P\""
      fill: "#fff"
      stroke: "#430"
      strokeThickness: 4
      align: "center"
    txtRank.anchor.setTo 0.5, 0.5
    txtName = game.add.text 20, -10, "",
      font: "16px \"Press Start 2P\""
      fill: "#fff"
      stroke: "#430"
      strokeThickness: 4
      align: "left"
    txtName.anchor.setTo 0.5, 0.5
    txtScore = game.add.text 150, -10, "",
      font: "16px \"Press Start 2P\""
      fill: "#fff"
      stroke: "#430"
      strokeThickness: 4
      align: "right"
    txtScore.anchor.setTo 0.5, 0.5
    for txt in [txtRank, txtName, txtScore]
      txt.lineSpacing = 15
    lbPanel.addChild txtRank
    lbPanel.addChild txtName
    lbPanel.addChild txtScore

    # add sprites for each position on lb

    for i in [0..MAXLB-1]
      spr = addHallSprite -120, -105 + i*41, 0
      btnTxt = game.add.text(0, 10, '',
        font: "16px \"04b_19regular\""
        fill: "#fff"
        stroke: "#430"
        strokeThickness: 4
        align: "center"
      )
      btnTxt.scale.setTo 0.5, 0.5
      btnTxt.smoothed = false
      btnTxt.anchor.setTo 0.5, 0.5
      spr.addChild btnTxt
      spr.kill()
      lbPanel.addChild spr
    # for i in [1..lb.length]
    #   txt = game.add.text -150, 30 * (lb.length/2 - i) + 30, "",
    #     font: "16px \"Press Start 2P\""
    #     fill: "#fff"
    #     stroke: "#430"
    #     strokeThickness: 4
    #     align: "left"
    #   txt.anchor.setTo 0
    #   lbPanel.addChild txt
    # game over panel
    gameOverPanel = game.add.sprite(game.world.width/2, game.world.height * 1.5, "gameover" ,0, gameOverGroup)
    gameOverPanel.anchor.setTo 0.5, 0.5
    gameOverPanel.kill()

    tryAgainText = game.add.text(0, gameOverPanel.height / 2 - 20, "Touch to Try Again",
      font: "8px \"Press Start 2P\""
      fill: "#fff"
      stroke: "#430"
      strokeThickness: 4
      align: "center"
    )
    tryAgainText.anchor.setTo 0.5, 0.5
    gameOverPanel.addChild tryAgainText

    gameOverScoreFixedTxt = gameOverScoreFixedTxt = game.add.text(gameOverPanel.width/4-10, -30, "Score\n\nBest",
      font: "24px \"04b_19regular\""
      fill: "#fff"
      stroke: "#430"
      strokeThickness: 4
      align: "left"
    )
    gameOverScoreFixedTxt.anchor.setTo 0, 0
    gameOverPanel.addChild gameOverScoreFixedTxt

    gameOverScoreTxt1 = game.add.text(gameOverPanel.width/4-10, 0, "",
      font: "16px \"04b_19regular\""
      fill: "#fff"
      stroke: "#430"
      strokeThickness: 4
      align: "left"
    )
    gameOverScoreTxt1.anchor.setTo 0, 0
    gameOverPanel.addChild gameOverScoreTxt1

    gameOverScoreTxt2 = game.add.text(gameOverPanel.width/4-10, 68, "",
      font: "16px \"04b_19regular\""
      fill: "#fff"
      stroke: "#430"
      strokeThickness: 4
      align: "left"
    )
    gameOverScoreTxt2.anchor.setTo 0, 0
    gameOverPanel.addChild gameOverScoreTxt2
    leaderboardButton = game.add.button -100, 0, 'leaderboard', showLeaderBoard, this, 0, 0, 1

    leaderboardButton.events.onInputUp.add ->
      clickSnd.play()
    #   console.log('sigh')
    # leaderboardButton.events.onInputOver.add ->
    #   hoverSnd.play()
    # leaderboardButton.setUpSound(hoverSnd)
    # leaderboardButton.setOverSound(clickSnd)
    leaderboardButton.scale.setTo 2, 2
    leaderboardButton.anchor.setTo 0.5, 0.5
    leaderboardButton.smoothed = false
    gameOverPanel.addChild leaderboardButton

    # add text input for name! can't add as a child, so will do jugaad...
    # nameInput = game.add.inputField -100, 50
    playerNameInput = game.add.inputField -100, 50,
      font: '16px "Press Start 2P"'
      fill: '#430'
      # cursorColor: "#00f"
      placeHolder: 'name'
      placeHolderColor: '#652'
      height: 20
      type: Fabrique.InputType.text
    , gameOverGroup
      # placeHolder: 'What'
      # font: '16px "Arial"'
      # fillAlpha: 0.5
      # height: 20
    
    # playerNameInput.anchor.setTo 0.5, 0.5
    # gameOverPanel.addChild playerNameInput


    playerNameInput.bringToTop()
    # hallTitleText = game.add.bitmapText(0, 0, 'flappyfont', "Choose your Hall bruh", 16, 'center');
    # hallTitleText = game.add.bitmapText(0, -50, 'flappyfont', "Hello World", 24);
    # hallTitleText.anchor.set 0.5
    

    # hallTitleText.anchor.setTo 0.5, 0.5
    # hallTitleText.visible = true;

    # Add sounds
    flapSnd = game.add.audio("flap")
    flapSnd.allowMultiple = true
    scoreSnd = game.add.audio("score")
    hurtSnd = game.add.audio("hurt")
    fallSnd = game.add.audio("fall")
    swooshSnd = game.add.audio("swoosh")
    hoverSnd = game.add.audio("hover")
    clickSnd = game.add.audio("click")
    # add txt field?

    
    # pass = game.add.inputField game.world.width/2, game.world.height/2,
    #   font: '16px "Press Start 2P"'
    #   fillAlpha: 0
    #   height: 20
    # # bg.addChild pass
    # pass.bringToTop()
    # bird is kill
    bird.kill()
    buttonList = []
    chooseHall()
    return

  chooseHall = ->
    # something
    console.log("choosing hall...")
    # add hall screen
    swooshSnd.play()
    hall = game.add.sprite(game.world.width/2, game.world.height * 1.5, "hall")
    # style = { font: "30px Arial", fill: "#ffffff" };  
    # hallTitleText = game.add.text(0, 0, "0", style);
    # hallTitleText = game.add.bitmapText(0, -100, 'flappyfont', "Choose your Hall", 24);
    hallTitleText = game.add.text(0, -100, "Choose Carefully",
      font: "30px \"04b_19regular\""
      fill: "#fff"
      stroke: "#430"
      strokeThickness: 4
      align: "center"
    )

    
    hallTitleText.renderable = true
    hallTitleText.anchor.setTo 0.5, 0.5
    # hallTitleText.anchor.set 0.5
    hall.addChild hallTitleText
    # hall.addChild(hall)
    hall.anchor.setTo 0.5, 0.5
    avWidth = hall.width - 50
    avHeight = hall.height - 100
    for num in [1..numHalls]
      num -= 1
      i = parseInt(num/4);
      j = num%4
      offx = -hall.width/2 + 72; 
      offy = -hall.height/2 + 120
      x = Math.round(avWidth/4*j + offx)
      y = Math.round(avHeight/3*i + offy)
      hall.addChild addButton(x, y, num+1)

    # hall.addChild buttonGroup
    # button = game.add.button 0, 0, 'bird', ->
    #   console.log('hey')
    # , this, 2, 1, 0
    # hall.addChild button
    # button.bringToTop
    tween = game.add.tween(hall).to(y:game.world.height / 2, 800, Phaser.Easing.Back.Out,true);

    
    # game.time.events.add 2000, ->
    #   # hide hall screen
    #   tween = game.add.tween(hall).to(y:game.world.height * 1.5, 800, Phaser.Easing.Back.In, true);
    #   tween.onComplete.add ->
    #     hall.kill()
    #   postHall()

  addButton = (x, y, idx) ->
    
    button = game.add.button x, y, 'sheet', ->
      postHall(idx) unless hallChosen
    , this, 
    hallList[idx-1] + '/3', 
    hallList[idx-1] + '/2', 
    hallList[idx-1] + '/1', 
    hallList[idx-1] + '/2'
    button.smoothed = false
    button.anchor.setTo 0.5, 0.5
    # console.log('added btton at' + x + y)
    button.animations.add "onHover", [
      hallList[idx-1] + '/1'
      hallList[idx-1] + '/2'
      hallList[idx-1] + '/3'
      hallList[idx-1] + '/2'
    ], 10, true
    button.scale.setTo 2, 2
    button.smoothed = false
    button.trueY = y
    btnTxt = game.add.text(0, 10, hallList[idx-1],
      font: "16px \"04b_19regular\""
      fill: "#fff"
      stroke: "#430"
      strokeThickness: 4
      align: "center"
    )
    btnTxt.scale.setTo 0.5, 0.5
    btnTxt.smoothed = false
    btnTxt.anchor.setTo 0.5, 0.5
    button.addChild btnTxt
    # using click for hover, and swoosh for click...
    button.setOverSound(clickSnd)
    button.setUpSound(swooshSnd)
    button.events.onInputOver.add ->
      button.play("onHover", 10, true, false)
      button.doBounce = true
    button.events.onInputOut.add ->
      button.animations.stop()
      button.doBounce = false
    button.doBounce = false
    buttonList.push(button)
    button


  # call this after hall is chosen, to set up game/keys 
  postHall = (idx)->
    console.log('chose hall' + idx)
    hallChosen = true
    chosenHall = idx-1
    for button in buttonList
      button.setOverSound(null)
      button.setUpSound(null)
    # Add bird
    bird = game.add.sprite(0, 0, "sheet", hallList[idx-1] + '/2')
    game.physics.arcade.enableBody(bird)
    hall.bringToTop()
    # need to scale up for small models..
    bird.scale.setTo 2, 2
    bird.anchor.setTo 0.5, 0.5
    bird.animations.add('fly', Phaser.Animation.generateFrameNames(hallList[idx-1] + '/', 1, 3, '', 1), 10, true);
    # bird.animations.add "fly", [
    #   0
    #   1
    #   2
    #   1
    # ], 10, true
    bird.body.collideWorldBounds = true
    # btnTxt = game.add.text(0, 20, hallList[idx-1],
    #   font: "16px \"04b_19regular\""
    #   fill: "#fff"
    #   stroke: "#430"
    #   strokeThickness: 4
    #   align: "center"
    # )
    # btnTxt.anchor.setTo 0.5, 0.5
    # bird.addChild btnTxt
    # bird.body.setSize bird.body.width, bird.body.height + 16
    # can't use polygons in arcade physics..
    # bird.body.setPolygon(
    #   24,1,
    #   34,16,
    #   30,32,
    #   20,24,
    #   12,34,
    #   2,12,
    #   14,2
    # )

    # disable all the buttons?
    tween = game.add.tween(hall).to(y:game.world.height * 1.5, 800, Phaser.Easing.Back.In, true);
    tween.onComplete.add ->
      for button in buttonList
        button.destroy()
      hall.destroy()
    # revive bird
    bird.angle = 0
    bird.revive()


    # Add controls
    spaceKey = game.input.keyboard.addKey(Phaser.Keyboard.SPACEBAR)
    spaceKey.onDown.add flap
    bg.events.onInputDown.add flap
    bg.events.onInputDown.add ->
      console.log("down pressed?")
    # RESET!
    reset()

  reset = ->
    spaceKey.onDown.removeAll()
    bg.events.onInputDown.removeAll()
    spaceKey.onDown.add flap    
    bg.events.onInputDown.add flap
    gameStarted = false
    gameOver = false
    score = 0
    # credits.renderable = true
    # credits.setText "see console log\nfor github url"
    scoreText.setText "Flappy Bird 2.2 Edition"
    instText.setText "TOUCH TO FLY\nFLAP bird WINGS"
    gameOverText.renderable = false
    bird.smoothed = false
    bird.body.allowGravity = false
    bird.reset game.world.width * 0.3, game.world.height / 2
    bird.angle = 0
    bird.animations.play "fly"
    tubes.removeAll()
    invs.removeAll()
    return

  start = ->
    # console.log("start called")
    # START!
    gameStarted = true
    # remove timer here for good measure. luckily doesn't break even if already removed
    game.time.events.remove(tubesTimer)
    # credits.renderable = false
    bird.body.allowGravity = true
    bird.body.gravity.y = GRAVITY

    # SPAWN tubeS!
    tubesTimer = game.time.events.loop 1 / SPAWN_RATE, spawntubes


    # Show score
    scoreText.setText score
    instText.renderable = false

    return

  update = ->
    if gameStarted
      if !gameOver
        # Make bird dive
        bird.angle = (90 * (FLAP + bird.body.velocity.y) / FLAP) - 180
        bird.angle = -30  if bird.angle < -30
        if bird.angle > 80
          bird.angle = 90
          bird.animations.stop('fly')
          bird.frame = hallList[chosenHall] + '/2'
        else
          bird.animations.play('fly')

        # Check game over
        game.physics.arcade.overlap bird, tubes, ->
          setGameOver()
          fallSnd.play()
        setGameOver() if not gameOver and bird.body.bottom >= GROUND_Y

        # Add score
        game.physics.arcade.overlap bird, invs, addScore

      else
        # rotate the bird to make sure its head hit ground
        tween = game.add.tween(bird).to(angle: 90, 100, Phaser.Easing.Bounce.Out, true);
        if bird.body.bottom >= GROUND_Y + 3
          bird.y = GROUND_Y - 13
          bird.body.velocity.y = 0
          bird.body.allowGravity = false
          bird.body.gravity.y = 0

    else
      bird.y = (game.world.height / 2) + 8 * Math.cos(game.time.now / 200)
      bird.angle = 0

    if !hallChosen
      for button in buttonList
        if button.doBounce
          button.y = button.trueY + 5 * Math.cos(game.time.now / 200)
        else
          button.y = button.trueY
   

    # Scroll ground
    bg.tilePosition.x -= game.time.physicsElapsed * SPEED/5 unless gameOver
    ground.tilePosition.x -= game.time.physicsElapsed * SPEED unless gameOver
    return

  render = ->
    if DEBUG
      game.debug.renderSpriteBody bird
      tubes.forEachAlive (tube) ->
        game.debug.renderSpriteBody tube
        return

      invs.forEach (inv) ->
        game.debug.renderSpriteBody inv
        return

    return

  state =
    preload: preload
    create: create
    update: update
    render: render

  game = new Phaser.Game(WIDTH, HEIGHT, Phaser.CANVAS, parent, state, false, false)
  # generate secret key
  secretKey = randomString(32, '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ');
  # Phaser.Canvas.setSmoothingEnabled(game.context, false);
  return

WebFontConfig =
  google:
    families: [ 'Press+Start+2P::latin' ]
  active: main
(->
  wf = document.createElement('script')
  wf.src = (if 'https:' == document.location.protocol then 'https' else 'http') +
    '://ajax.googleapis.com/ajax/libs/webfont/1/webfont.js'
  wf.type = 'text/javascript'
  wf.async = 'true'
  s = document.getElementsByTagName('script')[0]
  s.parentNode.insertBefore(wf, s)
)()