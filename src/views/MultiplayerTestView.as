package views
{
	import com.bit101.components.ColorChooser;
	import com.bit101.components.HBox;
	import com.bit101.components.Label;
	import com.bit101.components.VBox;
	
	import flash.events.Event;
	import flash.events.KeyboardEvent;
	import flash.events.MouseEvent;
	import flash.geom.Vector3D;
	import flash.ui.Keyboard;
	import flash.utils.ByteArray;
	import flash.utils.setTimeout;
	
	import away3d.cameras.lenses.PerspectiveLens;
	import away3d.controllers.HoverController;
	import away3d.debug.AwayStats;
	import away3d.lights.DirectionalLight;
	import away3d.lights.PointLight;
	import away3d.lights.shadowmaps.NearDirectionalShadowMapper;
	import away3d.materials.lightpickers.StaticLightPicker;
	import away3d.materials.methods.FilteredShadowMapMethod;
	import away3d.materials.methods.FogMethod;
	import away3d.materials.methods.FresnelSpecularMethod;
	import away3d.materials.methods.NearShadowMapMethod;
	import away3d.primitives.SkyBox;
	import away3d.primitives.WireframeCube;
	import away3d.primitives.WireframePlane;
	import away3d.primitives.WireframeSphere;
	import away3d.textures.BitmapCubeTexture;
	import away3d.utils.Cast;
	
	import awayphysics.collision.shapes.AWPStaticPlaneShape;
	import awayphysics.dynamics.AWPDynamicsWorld;
	import awayphysics.dynamics.AWPRigidBody;
	import awayphysics.dynamics.vehicle.AWPWheelInfo;
	
	import data.CarInstance;
	import data.SceneData;
	
	import loaders.AssetFactory;
	import loaders.AssetsLoader;
	
	import playerio.Client;
	import playerio.Connection;
	import playerio.Message;
	import playerio.PlayerIO;
	
	import potato.core.config.Config;
	
	import ui.ArrowButton;
	
	public class MultiplayerTestView extends Away3DView
	{
		public var btNext:ArrowButton;
		public var btPrev:ArrowButton;
		
		public var floor:WireframePlane;
		public var cube:WireframeCube;
		public var sphere:WireframeSphere;
		public var cameraController:HoverController;
		public var stats:AwayStats;
		
		//navigation variables
		private var move:Boolean = false;
		private var lastPanAngle:Number;
		private var lastTiltAngle:Number;
		private var lastMouseX:Number;
		private var lastMouseY:Number;
		
		private var bodyColorChooser:ColorChooser;
		private var rimsColorChooser:ColorChooser;
		
		//car models
		public var modelList : Array = [];
		//		public var currentModel : ObjectContainer3D;
		private var physicsWorld:AWPDynamicsWorld;
		private var _assetLoader:AssetsLoader;
		private var _assetFactory:AssetFactory;
		private var _timeStep:Number = 1.0 / 60;
		//navigation
		private var _prevPanAngle:Number;
		private var _prevTiltAngle:Number;
		private var _prevMouseX:Number;
		private var _prevMouseY:Number;
		private var _mouseMove:Boolean;
		private var currentCar:CarInstance;
		
		//light variables
		private var _sunLight:DirectionalLight;
		private var _skyLight:PointLight;
		private var _lightPicker:StaticLightPicker;
		
		//materials
		private var _skyMap:BitmapCubeTexture;
		private var _fog:FogMethod;
		private var _specularMethod:FresnelSpecularMethod;
		private var _shadowMethod:NearShadowMapMethod;
		
		//global light setting
		private var sunColor:uint = 0xAAAAA9;
		private var sunAmbient:Number = 0.4;
		private var sunDiffuse:Number = 0.5;
		private var sunSpecular:Number = 1;
		private var skyColor:uint = 0x333338;
		private var skyAmbient:Number = 0.2;
		private var skyDiffuse:Number = 0.3;
		private var skySpecular:Number = 0.5;
		private var fogColor:uint = 0x333338;
		
		override public function init():void
		{
	/*		*/
			super.init();
			_setup3D();
			_setupUI();
		
			ConnectToPlayerIO("Chris")
			
			stage.addEventListener(KeyboardEvent.KEY_UP, onKeyUp);
			stage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyDown);
			stage.addEventListener(Event.ENTER_FRAME, onEnterFrame);
			
		}
		
		private var client:Client;
		public function ConnectToPlayerIO(name:String):void{
			//	my_player_name = name;
			trace("Connecting")
			PlayerIO.connect(stage,MpConfig.game_id,"public", "user" ,"","", [], handlePlayerIOConnect)
		}
		
		public function CreateRoom(name:String):void{
			if(client == null) throw new Error("First connect to Player.IO webservice");
			trace("Creating room", name)
			client.multiplayer.createJoinRoom("GameJam2", MpConfig.room_type, true, {name:name}, {}, handleMultiplayerConnect);	
		}
		
		public function JoinRoom(id:String):void{
			if(client == null) throw new Error("First connect to Player.IO webservice");
			client.multiplayer.joinRoom(id, {}, handleMultiplayerConnect);
			
		}
		
		
		private function handlePlayerIOConnect(client:Client):void{
			this.client = client;
			if(MpConfig.use_development_server){
				client.multiplayer.developmentServer = MpConfig.development_server_config;
			}
			
			
			CreateRoom("My Fancy New Game");
		}
		
		private var connection:Connection
		private var cars:Object = {};
		private function handleMultiplayerConnect(connection:Connection):void{
			this.connection = connection;
		
			
			connection.addMessageHandler("m",function(m:Message, id:uint, ba:ByteArray):void{
				
				if(!cars[id])
					cars[id] = _assetFactory.addCar(0,0);
			
				cars[id].update(ba);
				
			})
			
			connection.addMessageHandler("time", function(m:Message, time:int):void{
				trace("Round is starting in", time)
				if(time==0){
					trace("Start Game!")
					setTimeout(function():void{
						trace("Requesting win!")
						connection.send("win");
					},10000)
				}
			})
			
			connection.addMessageHandler("reset", function(m:Message, offset:int):void{
				trace("Reset game, place me at", offset)
				//Offset declares the offset in the poll position where the player should start
				//Remember to lock players in place.
			})
			
			connection.addMessageHandler("won", function(m:Message, id:int):void{
				trace("player id won", id)
				//Offset declares the offset in the poll position where the player should start
				//Remember to lock players in place.
			})

			connection.addMessageHandler("left", function(m:Message, id:int):void{
				if(cars[id]){
					var instance:CarInstance = cars[id]
					_assetFactory.removeCar(instance)
				}
				delete cars[id]
				//Offset declares the offset in the poll position where the player should start
				//Remember to lock players in place.
			})
			
			
		}
		
		private var _engineForce:Number = 0;
		private var _keyLeft:Boolean = false;
		private var _keyRight:Boolean = false;
		private var _breakingForce:Number = 0;
		
		private function onKeyDown(event:KeyboardEvent):void
		{
			switch (event.keyCode) {
				case Keyboard.UP: 
				case Keyboard.W: 
				case Keyboard.Z: //fr
					_engineForce = 4500;
					break;
				case Keyboard.DOWN: 
				case Keyboard.S: 
					_engineForce = -4500;
					break;
				case Keyboard.LEFT: 
				case Keyboard.A: 
				case Keyboard.Q: //fr
					_keyLeft = true;
					break;
				case Keyboard.RIGHT: 
				case Keyboard.D: 
					_keyRight = true;
					break;
				case Keyboard.SPACE: 
					_breakingForce = 80;
					break;
				case Keyboard.R: 
					//resetGame();
					break;
			}
		}
		
		/**
		 * Key up listener
		 */
		private function onKeyUp(event:KeyboardEvent):void
		{
			switch (event.keyCode) {
				case Keyboard.UP: 
				case Keyboard.W: 
				case Keyboard.Z: //fr
					_engineForce = 0;
					break;
				case Keyboard.DOWN: 
				case Keyboard.S: 
					_engineForce = 0;
					break;
				case Keyboard.LEFT: 
				case Keyboard.A: 
				case Keyboard.Q: //fr
					_keyLeft = false;
					break;
				case Keyboard.RIGHT: 
				case Keyboard.D: 
					_keyRight = false;
					break;
				case Keyboard.SPACE: 
					_breakingForce = 0;
					break;
			}
		}
		
		private var t_engineForce:Number = 0;
		private var t_keyLeft:Boolean = false;
		private var t_keyRight:Boolean = false;
		private var _carCounter:Number = 0;
		
		private function onEnterFrame(e:Event):void{
			//Break execution
			if(currentCar == null) return;
			
			var doSend:Boolean = false;
			if(
				t_engineForce != _engineForce ||
				t_keyLeft != _keyLeft ||
				t_keyRight != _keyRight
			){
				doSend = true;
			}
			
			t_engineForce = _engineForce;
			t_keyLeft = _keyLeft;
			t_keyRight = _keyRight;
			
			if ( (doSend || _carCounter >= 10) && connection) {
				_carCounter = 0;
				
				
				
				var body:AWPRigidBody = currentCar.carVehicle.getRigidBody();
				var wheelInfo0:AWPWheelInfo = currentCar.carVehicle.getWheelInfo(0);
				var wheelInfo1:AWPWheelInfo = currentCar.carVehicle.getWheelInfo(1);
				var wheelInfo2:AWPWheelInfo = currentCar.carVehicle.getWheelInfo(2);
				var wheelInfo3:AWPWheelInfo = currentCar.carVehicle.getWheelInfo(3);
				var ba:ByteArray = serialize(_keyLeft,_keyRight, _engineForce, _breakingForce, currentCar.steering, body.position.clone(), body.rotation.clone(), body.linearVelocity.clone(), body.angularVelocity.clone(),
					wheelInfo0.worldPosition.clone(), wheelInfo0.rotation, wheelInfo0.deltaRotation,
					wheelInfo1.worldPosition.clone(), wheelInfo1.rotation, wheelInfo1.deltaRotation,
					wheelInfo2.worldPosition.clone(), wheelInfo2.rotation, wheelInfo2.deltaRotation,
					wheelInfo3.worldPosition.clone(), wheelInfo3.rotation, wheelInfo3.deltaRotation
				);
				//setTimeout(updateBody2, 1000, ba);
				
				connection.send("m", ba);
				
			}
			_carCounter++
			
			physicsWorld.step(_timeStep);
			currentCar.engineForce = _engineForce;
			currentCar.keyLeft = _keyLeft;
			currentCar.keyRight = _keyRight;
				
			currentCar.step();
			for(var x:String in cars){
				cars[x].step();
			}
			
			
		}
	
		
		private function serialize(
			
			keyLeft:Boolean,
			keyRight:Boolean,
			engineForce:Number,
			breakingForce:Number,
			steering:Number,
			
			position:Vector3D,
			rotation:Vector3D,
			linearVelocity:Vector3D,
			angularVelocity:Vector3D,
			
			position1:Vector3D,
			rotation1:Number,
			deltaRotation1:Number,
			
			position2:Vector3D,
			rotation2:Number,
			deltaRotation2:Number,
			
			position3:Vector3D,
			rotation3:Number,
			deltaRotation3:Number,
			
			position4:Vector3D,
			rotation4:Number,
			deltaRotation4:Number
		):ByteArray{
			var ba:ByteArray = new ByteArray();
			
			ba.writeBoolean(keyLeft);
			ba.writeBoolean(keyRight);
			ba.writeFloat(engineForce);
			ba.writeFloat(breakingForce);
			ba.writeFloat(steering);
			
			writeVector3d(ba, position);
			writeVector3d(ba, rotation);
			writeVector3d(ba, linearVelocity);
			writeVector3d(ba, angularVelocity);
			
			writeVector3d(ba, position1);
			ba.writeFloat(rotation1);
			ba.writeFloat(deltaRotation1);
			
			writeVector3d(ba, position2);
			ba.writeFloat(rotation2);
			ba.writeFloat(deltaRotation2);
			
			writeVector3d(ba, position3);
			ba.writeFloat(rotation3);
			ba.writeFloat(deltaRotation3);
			
			writeVector3d(ba, position4);
			ba.writeFloat(rotation4);
			ba.writeFloat(deltaRotation4);
			
			return ba;
			
		}
		
		private function writeVector3d(ba:ByteArray, d3:Vector3D):void{
			ba.writeFloat(d3.x);
			ba.writeFloat(d3.y);
			ba.writeFloat(d3.z);
		}
		
		private function readVector3D(ba:ByteArray):Vector3D{
			return new Vector3D(ba.readFloat(),ba.readFloat(),ba.readFloat(),0); 
		}
		
		private function _setup3D () : void
		{	
			cube = new WireframeCube(700,700);
			sphere = new WireframeSphere(350);
			//			modelList.push(cube);
			//			modelList.push(sphere);
			//			
			//			currentModel = modelList[User.selectedCarIndex]; 
			
			//			(currentModel as WireframePrimitiveBase).color = User.bodyColor;
			
			//			view3D.scene.addChild(currentModel);
			
			view3D.camera.lens = new PerspectiveLens(70);
			view3D.camera.lens.far = 30000;
			view3D.camera.lens.near = 1;
			
			physicsWorld = new AWPDynamicsWorld();
			physicsWorld.initWithDbvtBroadphase();
			physicsWorld.gravity = new Vector3D(0, -10, 0);
			
			_createFloor();
			
			initLights();
			//			cameraController = new HoverController(view3D.camera);
			//			cameraController.distance = 1000;
			//			cameraController.minTiltAngle = 0;
			//			cameraController.maxTiltAngle = 90;
			//			cameraController.panAngle = 45;
			//			cameraController.tiltAngle = 20;
			
			cameraController = new HoverController(view3D.camera, null, 90, 10, 500, 10, 90);
			cameraController.minTiltAngle = -60;
			cameraController.maxTiltAngle = 60;
			cameraController.autoUpdate = false;
			cameraController.wrapPanAngle = true;
			
			
			_assetLoader = new AssetsLoader();
			_assetLoader.addEventListener(Event.COMPLETE, onComplete);
			_assetLoader.startLoading();
			
			stage.addEventListener(MouseEvent.MOUSE_DOWN, onMouseDown);
			stage.addEventListener(MouseEvent.MOUSE_UP, onMouseUp);
			stage.addEventListener(MouseEvent.MOUSE_WHEEL, onMouseWheel);
			//			stage.addEventListener(Event.MOUSE_LEAVE, onMouseUp);
		}
		
		private function _createFloor():void
		{
			floor = new WireframePlane(700,700, 10,10,0xFFFFFF,1, "xz");
			view3D.scene.addChild(floor);
			
			var groundShape : AWPStaticPlaneShape = new AWPStaticPlaneShape(new Vector3D(0, 1, 0));
			var groundRigidbody : AWPRigidBody = new AWPRigidBody(groundShape, floor, 0);
			physicsWorld.addRigidBody(groundRigidbody);
			
		}private function initLights():void
		{
			//create a light for shadows that mimics the sun's position in the skybox
			_sunLight = new DirectionalLight();
			_sunLight.y = 1200;
			_sunLight.color = sunColor;
			_sunLight.ambientColor = sunColor;
			_sunLight.ambient = sunAmbient;
			_sunLight.diffuse = sunDiffuse;
			_sunLight.specular = sunSpecular;
			
			_sunLight.castsShadows = true;
			_sunLight.shadowMapper = new NearDirectionalShadowMapper(.1);
			view3D.scene.addChild(_sunLight);
			
			//create a light for ambient effect that mimics the sky
			_skyLight = new PointLight();
			_skyLight.color = skyColor;
			_skyLight.ambientColor = skyColor;
			_skyLight.ambient = skyAmbient;
			_skyLight.diffuse = skyDiffuse;
			_skyLight.specular = skySpecular;
			_skyLight.y = 1200;
			_skyLight.radius = 1000;
			_skyLight.fallOff = 2500;
			view3D.scene.addChild(_skyLight);
			
			
			//global methods
			_fog = new FogMethod(1000, 10000, 0x333338);
			_specularMethod = new FresnelSpecularMethod();
			_specularMethod.normalReflectance = 1.8;
			
			_shadowMethod = new NearShadowMapMethod(new FilteredShadowMapMethod(_sunLight));
			_shadowMethod.epsilon = .0007;
			
			//create light picker for materials
			_lightPicker = new StaticLightPicker([_sunLight, _skyLight]);
		}
		
		protected function onComplete(event:Event):void
		{
			for each (var sceneData:SceneData in _assetLoader.sceneAssets)
			{
				sceneData.lightPicker = _lightPicker;
				
				//materials
				sceneData.skyMap = _skyMap;
				sceneData.fog = _fog;
				sceneData.specularMethod = _specularMethod;
				sceneData.shadowMethod = _shadowMethod;
				
				//global light setting
				sceneData.sunColor = sunColor;
				sceneData.sunAmbient = sunAmbient;
				sceneData.sunDiffuse = sunDiffuse;
				sceneData.sunSpecular = sunSpecular;
				sceneData.skyColor = skyColor;
				sceneData.skyAmbient = skyAmbient;
				sceneData.skyDiffuse = skyDiffuse;
				sceneData.skySpecular = skySpecular;
				sceneData.fogColor = fogColor;
			}
			
			_assetFactory = new AssetFactory(view3D, physicsWorld, _assetLoader);
			currentCar = _assetFactory.addCar(User.selectedCarIndex,0);
			
			/*currentCar.carVehicle.applyEngineForce(10,0)
			currentCar.carVehicle.applyEngineForce(10,1)
			currentCar.carVehicle.applyEngineForce(10,2)
			currentCar.carVehicle.applyEngineForce(10,3)*/
			
			//generate cube texture for sky
			_skyMap = new BitmapCubeTexture(
				Cast.bitmapData(_assetLoader.imageAssets[0]), Cast.bitmapData(_assetLoader.imageAssets[3]),
				Cast.bitmapData(_assetLoader.imageAssets[1]), Cast.bitmapData(_assetLoader.imageAssets[4]),
				Cast.bitmapData(_assetLoader.imageAssets[2]), Cast.bitmapData(_assetLoader.imageAssets[5])
			);
			
			//create the skybox
			view3D.scene.addChild(new SkyBox(_skyMap));
		}
		
		private function _setupUI () : void
		{
			btPrev = new ArrowButton();
			btPrev.addEventListener(MouseEvent.CLICK, _prev);
			btPrev.rotation = 90;
			btPrev.x = btPrev.width;
			btPrev.y = int(stage.stageHeight*.5);
			
			btNext = new ArrowButton();
			btNext.addEventListener(MouseEvent.CLICK, _next);
			btNext.rotation = -90;
			btNext.x = stage.stageWidth - btNext.width;
			btNext.y = btPrev.y;
			
			var vBox : VBox = new VBox(this, 100, 100);
			var hBox : HBox = new HBox(vBox);
			var label : Label = new Label(hBox, 0, 0, "Body color:");
			bodyColorChooser = new ColorChooser(hBox, 0, 0, User.bodyColor, _changeBodyColor);
			bodyColorChooser.usePopup = true;
			
			
			hBox = new HBox(vBox);
			label = new Label(hBox, 0, 0, "Rims color:");
			rimsColorChooser = new ColorChooser(hBox, 0, 0, User.rimsColor, _changeRimsColor);
			rimsColorChooser.usePopup = true;
			
			addChild(btPrev);
			addChild(btNext);
			addChild(stats = new AwayStats(view3D))
		}
		
		private function _changeRimsColor(event:Event):void
		{
			User.rimsColor = rimsColorChooser.value;
			
			_assetFactory.setRimColor(currentCar, User.rimsColor);
			//_updateColors();
		}
		
		private function _changeBodyColor(event:Event):void
		{
			User.bodyColor = bodyColorChooser.value;	
			
			_assetFactory.setBodyColor(currentCar, User.bodyColor);
			//_updateColors();
		}		
		
		
		override public function dispose () : void 
		{
			removeChild(stats);
			
			stage.removeEventListener(MouseEvent.MOUSE_DOWN, onMouseDown);
			stage.removeEventListener(MouseEvent.MOUSE_UP, onMouseUp);
			
			super.dispose();
		}
		
		override protected function render ( event : Event ) : void
		{
			
			
			if (move)
			{	
				cameraController.panAngle = 0.3*(stage.mouseX - lastMouseX) + lastPanAngle;
				cameraController.tiltAngle = 0.3*(stage.mouseY - lastMouseY) + lastTiltAngle;
			}
			else
			{
				//				modelList[User.selectedCarIndex].rotationY += 1;
			}
			
			
			cameraController.update();
			
			_skyLight.position = view3D.camera.position;
			super.render(event);
		}
		
		private function onMouseDown(event:MouseEvent):void
		{
			lastPanAngle = cameraController.panAngle;
			lastTiltAngle = cameraController.tiltAngle;
			lastMouseX = stage.mouseX;
			lastMouseY = stage.mouseY;
			move = true;
			stage.addEventListener(Event.MOUSE_LEAVE, onStageMouseLeave);
		}
		
		private function onMouseUp(event:MouseEvent):void
		{
			move = false;
			stage.removeEventListener(Event.MOUSE_LEAVE, onStageMouseLeave);
		}
		
		private function onMouseWheel(ev:MouseEvent):void
		{
			cameraController.distance -= ev.delta * 5;
			
			if (cameraController.distance < 100)
				cameraController.distance = 100;
			else if (cameraController.distance > 2000)
				cameraController.distance = 2000;
		}
		
		private function onStageMouseLeave(event:Event):void
		{
			move = false;
			stage.removeEventListener(Event.MOUSE_LEAVE, onStageMouseLeave);
		}
		
		private function _prev ( event : Event = null ) : void
		{
			_changeModel(-1);
		}
		
		private function _next ( event : Event = null ) : void
		{
			_changeModel(1);
		}
		
		private function _changeModel (direction:int = 1) : void
		{
			//			view3D.scene.removeChild(currentModel);
			_assetFactory.removeCar(currentCar);
			
			if ( direction < 0 )
			{
				if ( --User.selectedCarIndex <= 0 )
				{
					User.selectedCarIndex = modelList.length - 1;
				}
			}
			else
			{
				if ( ++User.selectedCarIndex >= modelList.length )
				{
					User.selectedCarIndex = 0;
				}
			}
			
			currentCar = _assetFactory.addCar(0,0);
			cameraController.targetObject = currentCar.bodyMesh

			//			currentModel = _assetFactory.addCar(User.selectedCarIndex).carContainer;
			//view3D.scene.addChild(currentModel);
			
			_assetFactory.setBodyColor(currentCar, User.bodyColor);
			_assetFactory.setRimColor(currentCar, User.rimsColor);
			
			//_updateColors();
		}
		
		private function _updateColors () : void
		{
			//			(currentModel as WireframePrimitiveBase).color = User.bodyColor;
		}
	}
}