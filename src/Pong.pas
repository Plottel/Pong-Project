program Pong;
uses SwinGame, sgSprites, sgTypes, sysutils;

{
	Abilities operate:
		Ready when program starts
		Hit button, active = true
		Hit ball, active = false AND ready = false AND StartTimer()
		Each frame, if timer >= COOLDOWN, ready = true AND StopTimer()
		ResetPoint StopTimer() AND ready = true
}

{ DEVELOPMENT TODO

	Animations work correctly
	Abilities need to influence speed/ball velocity
	Handle top/bottom collisions
	Draw/reset points and such
	MENU
	Copy everything to right paddle
	AI - easy
	AI - hard
	Instruction animations on menu
}

const
	PI = 3.1415926;
	DEGREES_TO_RADIANS = PI / 180;
	POWER_SHOT_COOLDOWN = 10000;
	SPEED_BOOST_COOLDOWN = 10000;
	SPEED_BOOST_DURATION = 3000;
	PADDLE_X_OFFSET = 30;
	PADDLE_Y_OFFSET = 20;
	BALL_X_OFFSET = 0;
	BALL_Y_OFFSET = 0;

type
	GameState = (MENU, MULTIPLAYER);
	PaddleAnimations = (Normal, NormalPS, ActivatePS, NormalSB, ActivateSB, SBUp, SBDown, NormalBoth, BothUp, BothDown);

	PaddleData = record
		paddleSprite: Sprite;
		speed, score: Integer;
		hitBox: Rectangle;
		left, right, top, bottom, midY: Single;
		powerShotActive, powerShotReady, speedBoostActive, speedBoostReady: Boolean;
		powerShotCooldown, speedBoostCooldown: Timer;
		currentAnimation: PaddleAnimations;
		showFlames: Boolean;
	end;

	BallData = record
		ballSprite: Sprite;
		angle: Single;
		hitBox: Rectangle;
		speed, tempSpeed, hits: Integer;
		moving, accelerated: Boolean;
		left, right, top, bottom, midY: Single;
	end;

	InterfaceData = record
		scoreboard, cooldownBar: Bitmap;
		leftScore, leftPowerShot, leftSpeedBoost, leftPSCD, leftSBCD: Rectangle;
		rightScore, rightPowerShot, rightSpeedBoost, rightPSCD, rightSBCD: Rectangle;
	end;

	GameData = record
		leftPaddle: PaddleData;
		rightPaddle: PaddleData;
		ball: BallData;
	end;

procedure SetupPaddle(var toSetup: PaddleData; const x, y: Single);
begin
	//Assign drawing and collision dimensions
	SpriteSetX(toSetup.paddleSprite, x);
	SpriteSetY(toSetup.paddleSprite, y);
	toSetup.hitBox.x := SpriteX(toSetup.paddleSprite) + PADDLE_X_OFFSET;
	toSetup.hitBox.y := SpriteY(toSetup.paddleSprite) + PADDLE_Y_OFFSET;
	toSetup.hitBox.width := SpriteWidth(toSetup.paddleSprite) - (PADDLE_X_OFFSET * 2);
	toSetup.hitBox.height := SpriteHeight(toSetup.paddleSPrite) - (PADDLE_Y_OFFSET * 2);

	//Assign other variables
	toSetup.speed := 5;
	toSetup.score := 0;
	toSetup.powerShotActive := false;
	toSetup.powerShotReady := true;
	toSetup.speedBoostActive := false;
	toSetup.speedBoostReady := true;
	toSetup.powerShotCooldown := CreateTimer();
	toSetup.speedBoostCooldown := CreateTimer();
	toSetup.showFlames := false;
end;

procedure SetupBall(var toSetup: BallData; const x, y: Single);
begin
	//Assign position and collision variables
	SpriteSetX(toSetup.ballSprite, x);
	SpriteSetY(toSetup.ballSprite, y);
	toSetup.hitBox.x := SpriteX(toSetup.ballSprite) + BALL_X_OFFSET;
	toSetup.hitBox.y := SpriteY(toSetup.ballSprite) + BALL_Y_OFFSET;
	toSetup.hitBox.width := SpriteWidth(toSetup.ballSprite) - (BALL_X_OFFSET * 2);
	toSetup.hitBox.height := SpriteHeight(toSetup.ballSprite) - (BALL_Y_OFFSET * 2);

	//Assign other ball variables
	toSetup.moving := false;
	toSetup.accelerated := false;
	toSetup.speed := 5;
	toSetup.hits := 0;
end;

procedure SetupInterface(var toSetup: InterfaceData);
begin
	toSetup.scoreboard := BitmapNamed('ScoreBoard');
	toSetup.cooldownBar := BitmapNamed('CooldownBar');
	//SETUP SCORES
	toSetup.leftPowerShot := CreateRectangle(5, 9, 130, 20);
	toSetup.leftSpeedBoost := CreateRectangle(5, 44, 130, 20);
	//4, 4, 92, 12
	toSetup.leftPSCD := CreateRectangle((ScreenWidth() / 2) - 256, 10, 92, 12);
	toSetup.leftSBCD := CreateRectangle((ScreenWidth / 2) - 256, 45, 92, 12);
end;

procedure UpdateBallHitBox(var toUpdate: BallData);
begin
	toUpdate.hitBox.x := SpriteX(toUpdate.ballSprite) + BALL_X_OFFSET;
	toUpdate.hitBox.y := SpriteY(toUpdate.ballSprite) + BALL_Y_OFFSET;
	toUpdate.hitBox.width := SpriteWidth(toUpdate.ballSprite) - (BALL_X_OFFSET * 2);
	toUpdate.hitBox.height := SpriteHeight(toUpdate.ballSprite) - (BALL_Y_OFFSET * 2);
end;

procedure UpdatePaddleHitBox(var toUpdate: PaddleData);
begin
	toUpdate.hitBox.x := SpriteX(toUpdate.paddleSprite) + PADDLE_X_OFFSET;
	toUpdate.hitBox.y := SpriteY(toUpdate.paddleSprite) + PADDLE_Y_OFFSET;
	toUpdate.hitBox.width := SpriteWidth(toUpdate.paddleSprite) - (PADDLE_X_OFFSET * 2);
	toUpdate.hitBox.height := SpriteHeight(toUpdate.paddleSPrite) - (PADDLE_Y_OFFSET * 2);
end;

procedure UpdateHitBoxes(var toUpdate: GameData);
begin
	UpdateBallHitBox(toUpdate.ball);
	UpdatePaddleHitBox(toUpdate.leftPaddle);
	UpdatePaddleHitBox(toUpdate.rightPaddle);
end;

function CalculateCooldownBar(const hud: InterfaceData; const paddle: PaddleData; const timer: Timer; const ability: String): Integer;
var
	maxWidth, timerDifference, abilityCooldown: Integer;
	millisecondsPerPixel: Single;
begin
	maxWidth := 92;

	if ability = 'Power Shot' then abilityCooldown := POWER_SHOT_COOLDOWN;
	if ability = 'Speed Boost' then abilityCooldown := SPEED_BOOST_COOLDOWN;


	millisecondsPerPixel := abilityCooldown / maxWidth;
	timerDifference := abilityCooldown - TimerTicks(timer);

	result := Round(maxWidth - (timerDifference / millisecondsPerPixel));
end;

function CheckBallXCollisions(const toCheck: BallData): Boolean;
begin
	result := false;

	if (toCheck.hitBox.x <= 0) or (toCheck.hitBox.x + toCheck.hitBox.width >= ScreenWidth()) then
	begin
		result := true;
	end;
end;

function CheckBallYCollisions(const toCheck: BallData): Boolean;
begin
	result := false;

	if (toCheck.hitBox.y <= 0) or (toCheck.hitBox.y + toCheck.hitBox.height >= ScreenHeight()) then
	begin
		result := true;
	end;
end;

function CalculateBallAngle(var ball: BallData; const paddle: PaddleData): Single;
var
	minAngle, maxAngle: Integer;
	anglePerPixel, offset: Single;
begin
	minAngle := 10;
	maxAngle := 70;
	anglePerPixel := (maxAngle - minAngle) / (paddle.hitBox.height / 2);
	offset := RectangleCenter(ball.hitBox).y - RectangleCenter(paddle.hitBox).y;

	if offset >= 0 then result := -minAngle + (anglePerPixel * offset);
	if offset < 0 then result := minAngle + (anglePerPixel * offset);
end;

procedure CheckBallCollisions(var toCheck: GameData);
begin
	//Check collisions against wall
	if CheckBallXCollisions(toCheck.ball) then SpriteSetDx(toCheck.ball.ballSprite, -SpriteDx(toCheck.ball.ballSprite));	
	if CheckBallYCollisions(toCheck.ball) then SpriteSetDy(toCheck.ball.ballSprite, -SpriteDy(toCheck.ball.ballSprite));

	//Check collisions against paddles
	if RectanglesIntersect(toCheck.ball.hitBox, toCheck.leftPaddle.hitBox) then
	begin
		//Assign new ball angle
		toCheck.ball.angle := CalculateBallAngle(toCheck.ball, toCheck.leftPaddle);

		toCheck.ball.hits += 1;
		if toCheck.ball.hits = 3 then
		begin
			toCheck.ball.speed += 1;
			toCheck.ball.hits := 0;
		end;

		SpriteSetDx(toCheck.ball.ballSprite, cos(toCheck.ball.angle * DEGREES_TO_RADIANS));
		SpriteSetDy(toCheck.ball.ballSprite, sin(toCheck.ball.angle * DEGREES_TO_RADIANS));

		if toCheck.leftPaddle.powerShotActive then
		begin
			toCheck.leftPaddle.powerShotActive := false;
			StartTimer(toCheck.leftPaddle.powerShotCooldown);

			if toCheck.leftPaddle.showFlames then
			begin
				SpriteStartAnimation(toCheck.leftPaddle.paddleSprite, 'SBNormal');
				toCheck.leftPaddle.currentAnimation := NormalSB
			end
			else
			begin
				SpriteStartAnimation(toCheck.leftPaddle.paddleSprite, 'Normal');
				toCheck.leftPaddle.currentAnimation := Normal;
			end;
		end;
	end;
end;			

procedure UpdateBall(var toUpdate: GameData);
var
	i: Integer;
begin
	for i := 0 to toUpdate.ball.speed do
	begin		
		UpdateSprite(toUpdate.ball.ballSprite);
		UpdateHitBoxes(toUpdate); 

		//Update collision variables
		toUpdate.ball.hitBox.x := SpriteX(toUpdate.ball.ballSprite) + BALL_X_OFFSET;
		toUpdate.ball.hitBox.y := SpriteY(toUpdate.ball.ballSprite) + BALL_Y_OFFSET;
		toUpdate.ball.hitBox.width := SpriteWidth(toUpdate.ball.ballSprite) - (BALL_X_OFFSET * 2);
		toUpdate.ball.hitBox.height := SpriteHeight(toUpdate.ball.ballSprite) - (BALL_Y_OFFSET * 2);

		CheckBallCollisions(toUpdate);		
	end;
end;

procedure HandleInput(var gData: GameData);
begin
	if KeyTyped(SpaceKey) then
	begin
		gData.ball.moving := true;
		gData.ball.angle := 60;
		SpriteSetDx(gData.ball.ballSprite, cos(gData.ball.angle * DEGREES_TO_RADIANS));
		SpriteSetDy(gData.ball.ballSprite, sin(gData.ball.angle * DEGREES_TO_RADIANS));
	end;

	if KeyTyped(WKey) then
	begin
		SpriteSetDy(gData.leftPaddle.paddleSprite, SpriteDy(gData.leftPaddle.paddleSprite) - gData.leftPaddle.speed);

		if (not (gData.leftPaddle.currentAnimation = ActivatePS)) and (gData.leftPaddle.showFlames) then
		begin
			if gData.leftPaddle.powerShotActive then
			begin
				SpriteStartAnimation(gData.leftPaddle.paddleSprite, 'BothUp');
				gData.leftPaddle.currentAnimation := BothUp
			end
			else
			begin
				SpriteStartAnimation(gData.leftPaddle.paddleSprite, 'SBUp');
				gData.leftPaddle.currentAnimation := SBUp;
			end;
		end;
	end;

	if KeyReleased(WKey) then
	begin
		SpriteSetDy(gData.leftPaddle.paddleSprite, SpriteDy(gData.leftPaddle.paddleSprite) + gData.leftPaddle.speed);

		if KeyDown(SKey) then
		begin
			if (not (gData.leftPaddle.currentAnimation = ActivatePS)) and (gData.leftPaddle.showFlames) then
			begin
				if gData.leftPaddle.powerShotActive then
				begin
					SpriteStartAnimation(gData.leftPaddle.paddleSprite, 'BothDown');
					gData.leftPaddle.currentAnimation := BothDown
				end
				else
				begin
					SpriteStartAnimation(gData.leftPaddle.paddleSprite, 'SBDown');
					gData.leftPaddle.currentAnimation := SBDown;
				end;
			end;
		end;		
	end;

	if KeyTyped(SKey) then
	begin
		SpriteSetDy(gData.leftPaddle.paddleSprite, SpriteDy(gData.leftPaddle.paddleSprite) + gData.leftPaddle.speed);

		if (not (gData.leftPaddle.currentAnimation = ActivatePS)) and (gdata.leftPaddle.showFlames) then
		begin
			if gData.leftPaddle.powerShotActive then
			begin
				SpriteStartAnimation(gData.leftPaddle.paddleSprite, 'BothDown');
				gData.leftPaddle.currentAnimation := BothDown
			end
			else
			begin
				SpriteStartAnimation(gData.leftPaddle.paddleSprite, 'SBDown');
				gData.leftPaddle.currentAnimation := SBDown;
			end;
		end;
	end;

	if KeyReleased(SKey) then
	begin
		SpriteSetDy(gData.leftPaddle.paddleSprite, SpriteDy(gData.leftPaddle.paddleSprite) - gData.leftPaddle.speed);

		if KeyDown(WKey) then
		begin
			if (not (gData.leftPaddle.currentAnimation = ActivatePS)) and (gData.leftPaddle.showFlames) then
			begin
				if gData.leftPaddle.powerShotActive then
				begin		
					SpriteStartAnimation(gData.leftPaddle.paddleSprite, 'BothUp');
					gData.leftPaddle.currentAnimation := BothUp
				end
				else
				begin
					SpriteStartAnimation(gData.leftPaddle.paddleSprite, 'SBUp');
					gData.leftPaddle.currentAnimation := SBUp;
				end;
			end;
		end;		
	end;

	if ((not KeyDown(WKey)) and (not KeyDown(SKey))) or (KeyDown(WKey)) and (KeyDown(SKey)) then
	begin
		if (not (gData.leftPaddle.currentAnimation = ActivatePS)) and (not (gData.leftPaddle.currentAnimation = ActivateSB)) then
		begin

			if (gData.leftPaddle.showFlames) and (gData.leftPaddle.powerShotActive) then
			begin
				SpriteStartAnimation(gData.leftPaddle.paddleSprite, 'BothNormal');
				gData.leftPaddle.currentAnimation := NormalBoth
			end
			else if gData.leftPaddle.showFlames then
			begin
				SpriteStartAnimation(gData.leftPaddle.paddleSprite, 'SBNormal');
				gData.leftPaddle.currentAnimation := NormalSB
			end
			else if gData.leftPaddle.powerShotActive then
			begin
				SpriteStartAnimation(gData.leftPaddle.paddleSprite, 'PSNormal');
				gData.leftPaddle.currentAnimation := NormalPS
			end
			else
			begin
				SpriteStartAnimation(gData.leftPaddle.paddleSprite, 'Normal');
				gData.leftPaddle.currentAnimation := Normal;
			end;
		end;
	end;

	if (KeyTyped(LeftCtrlKey)) and (gData.leftPaddle.powerShotReady) then
	begin
		SpriteStartAnimation(gData.leftPaddle.paddleSprite, 'ActivatePS');
		gData.leftPaddle.currentAnimation := ActivatePS;
		gData.leftPaddle.powerShotActive := true;
		gData.leftPaddle.powerShotReady := false;
	end;

	if (KeyTyped(LeftShiftKey)) and (gData.leftPaddle.speedBoostReady) then
	begin
		SpriteStartAnimation(gData.leftPaddle.paddleSprite, 'ActivateSB');
		gData.leftPaddle.currentAnimation := ActivateSB;
		gData.leftPaddle.speedBoostActive := true;
		gData.leftPaddle.speedBoostReady := false;
		StartTimer(gData.leftPaddle.speedBoostCooldown);
	end;
end;

procedure UpdatePaddle(var toUpdate: PaddleData);
begin
	UpdateSprite(toUpdate.paddleSprite);
	UpdatePaddleHitBox(toUpdate);

	//Update power shot
	if TimerTicks(toUpdate.powerShotCooldown) >= POWER_SHOT_COOLDOWN then
	begin
		toUpdate.powerShotReady := true;
		StopTimer(toUpdate.powerShotCooldown);
	end;

	//Update speed boost
	if TimerTicks(toUpdate.speedBoostCooldown) >= SPEED_BOOST_DURATION then
	begin
		toUpdate.showFlames := false;
		toUpdate.speedBoostActive := false;		
	end;

	if TimerTicks(toUpdate.speedBoostCooldown) >= SPEED_BOOST_COOLDOWN then
	begin
		toUpdate.speedBoostReady := true;
		StopTimer(toUpdate.speedBoostCooldown);
	end;

	//Check wall collisions
	if (toUpdate.hitBox.y <= 0) or (toUpdate.hitBox.y + toUpdate.hitBox.height >= ScreenHeight()) then
	begin
		SpriteSetY(toUpdate.paddleSprite, SpriteY(toUpdate.paddleSprite) - SpriteDy(toUpdate.paddleSprite));
	end;

	if (toUpdate.currentAnimation = ActivatePS) and (SpriteAnimationHasEnded(toUpdate.paddleSprite)) then
	begin
		toUpdate.currentAnimation := NormalPS;
		SpriteStartAnimation(toUpdate.paddleSprite, 'PSNormal');
	end;

	if (toUpdate.currentAnimation = ActivateSB) and (SpriteAnimationHasEnded(toUpdate.paddleSprite)) then
	begin
		toUpdate.showFlames := true;
		toUpdate.currentAnimation := NormalSB;
		SpriteStartAnimation(toUpdate.paddleSprite, 'SBNormal');
	end;
end;

procedure UpdateInterface(var toUpdate: InterfaceData; const gData: GameData);
begin
	if gData.leftPaddle.powerShotReady then
	begin
		toUpdate.leftPSCD.width := 92
	end
	else
	begin
		toUpdate.leftPSCD.width := CalculateCooldownBar(toUpdate, gData.leftPaddle, gData.leftPaddle.powerShotCooldown, 'Power Shot');
	end;

	if gData.leftPaddle.speedBoostReady then
	begin
		toUpdate.leftSBCD.width := 92
	end
	else
	begin
		toUpdate.leftSBCD.width := CalculateCooldownbar(toUpdate, gData.leftPaddle, gData.leftPaddle.speedBoostCooldown, 'Speed Boost');
	end;
end;

procedure UpdateGame(var gData: GameData; var hud: InterfaceData);
begin
	HandleInput(gData);
	UpdateInterface(hud, gData);
	UpdateBall(gData);
	UpdatePaddle(gData.leftPaddle);
end;

procedure SetupGame(var toSetup: GameData);
begin
	SetupPaddle(toSetup.leftPaddle, 30 - PADDLE_X_OFFSET, (ScreenHeight() / 2) - (SpriteHeight(toSetup.leftPaddle.paddleSprite) / 2));
	SetupPaddle(toSetup.rightPaddle, ScreenWidth() - SpriteWidth(toSetup.rightPaddle.paddleSprite) - 30, (ScreenHeight() / 2) - (SpriteHeight(toSetup.rightPaddle.paddleSprite) / 2));
	SetupBall(toSetup.ball, (ScreenWidth() / 2) - (SpriteWidth(toSetup.ball.ballSprite) / 2), (ScreenHeight() / 2) - (SpriteHeight(toSetup.ball.ballSprite) / 2));
end;

procedure DrawInterface(const toDraw: InterfaceData; const gData: GameData);
begin
	DrawBitmap(toDraw.scoreboard, (ScreenWidth() / 2) - (BitmapWidth(toDraw.scoreboard) / 2), 5);
	DrawBitmap(toDraw.cooldownBar, (ScreenWidth() / 2) - 260, 6);
	DrawBitmap(toDraw.cooldownBar, (ScreenWidth() / 2) - 260, 41);
	DrawText('POWERSHOT', ColorWhite, ColorBlack, 'GameFont', AlignCenter, toDraw.leftPowerShot); 
	DrawText('SPEED BOOST', ColorWhite, ColorBlack, 'GameFont', AlignCenter, toDraw.leftSpeedBoost);

	if gData.leftPaddle.powerShotReady then
	begin
		DrawText('PRESS CTRL', ColorWhite, ColorBlack, 'SmallGameFont', AlignCenter, toDraw.leftPSCD)
	end
	else
	begin
		FillRectangle(ColorBlue, toDraw.leftPSCD);
	end;

	if gData.leftPaddle.speedBoostReady then
	begin
		DrawText('PRESS SHIFT', ColorWhite, ColorBlack, 'SmallGameFont', AlignCenter, toDraw.leftSBCD);
	end
	else
	begin
		FillRectangle(ColorRed, toDraw.leftSBCD);
	end;
end;

procedure DrawGame(const toDraw: GameData; const hud: InterfaceData);
begin
	DrawInterface(hud, toDraw);
	DrawSprite(toDraw.leftPaddle.paddleSprite);
	DrawSprite(toDraw.rightPaddle.paddleSprite);
	DrawSprite(toDraw.ball.ballSprite);
end;

procedure Main();
var
	gData: GameData;
	hud: InterfaceData;
begin
	LoadResourceBundleNamed('Pong', 'Pong.txt', false);
	LoadBitmapNamed('grayPaddle', 'gray_paddle.png');
	LoadBitmapNamed('grayBall', 'gray_ball.png');

	gData.leftPaddle.paddleSprite := CreateSprite(BitmapNamed('Paddle'), AnimationScriptNamed('PaddleAnimations'));
	gData.rightPaddle.paddleSprite := CreateSprite(BitmapNamed('grayPaddle'));
	gData.ball.ballSprite := CreateSprite(BitmapNamed('Ball'));

	OpenGraphicsWindow('Pong', 800, 600);
	SetupGame(gData);
	SetupInterface(hud);
	
	repeat
		ProcessEvents();
		ClearScreen(ColorBlack);
		UpdateGame(gData, hud);		
		DrawGame(gData, hud);
		RefreshScreen(60);
	until WindowCloseRequested();
end;


begin
	Main();
end.