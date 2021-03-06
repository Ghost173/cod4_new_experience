#include code\common;

init()
{
	if( isDefined( level.flyingPlane ) )
	{
		self iPrintLnBold( "AGM not available" );
		return false;
	}
	else if( isDefined( self.pers[ "lastAGMUse" ] ) && getTime() - self.pers[ "lastAGMUse" ] < 25000 )
	{
		time = int( 25 - ( getTime() - self.pers[ "lastAGMUse" ] ) / 1000 );
		self iPrintLnBold( "JET REARMING - ETA " + time + " SECONDS" );
		return false;
	}
	
	if( self isProning() )
	{
		self iPrintLnBold( "You must stand to use this killstreak!" );
		return false;
	}
	
	level.flyingPlane = true;
	
	self thread setup();
	
	if( isDefined( self.moneyhud ) )
		self.moneyhud destroy();
	
	return true;
}

setup()
{
	self thread notifyTeamLn( "Friendly AGM called by^1 " + self.name );
	
	waittillframeend;
	
	self hide();
	
	waittillframeend;
	
	thread onPlayerDisconnect( self );
	self thread onGameEnd( ::endHardpoint );
	self thread onPlayerDeath( ::endHardpoint );
	self thread initialVisionSettings();
	
	waittillframeend;
	
	self thread godMod();
	self setClientDvar( "ui_hud_hardcore", 1 );
	
	waittillframeend;
	
	self.oldPosition = self getOrigin();
	self thread planeSetup();
	self thread infoHUD();
	
	waittillframeend;
	
	self thread planeTimer();
	self thread hudLogic( "normal" );
	self thread launcher();
	self disableWeapons();
	
	waittillframeend;
	
	self thread targetMarkers();
}

infoHUD()
{
	self endon( "disconnect" );
	level endon( "game_ended" );
	level endon( "flyOver" );
	
	self.info = [];
	
	self.info[ 0 ] = newClientHudElem( self );
	self.info[ 0 ].elemType = "font";
	self.info[ 0 ].x = 0;
	self.info[ 0 ].y = 60;
	self.info[ 0 ].alignX = "center";
	self.info[ 0 ].alignY = "top";
	self.info[ 0 ].horzAlign = "center";
	self.info[ 0 ].vertAlign = "top";
	self.info[ 0 ] setText( "Press ^1[{+attack}] ^7to ^1fire^7, press ^2[{+melee}] ^7to ^2simplify HUD" );
	//self.info[ 0 ].color = ( 0.0, 0.8, 0.0 );
	self.info[ 0 ].fontscale = 1.4;
	self.info[ 0 ].archived = 0;
	
	self.info[ 1 ] = newClientHudElem(self);
	self.info[ 1 ].elemType = "font";
	self.info[ 1 ].x = -32;
	self.info[ 1 ].y = -45;
	self.info[ 1 ].alignX = "center";
	self.info[ 1 ].alignY = "bottom";
	self.info[ 1 ].horzAlign = "center";
	self.info[ 1 ].vertAlign = "bottom";
	self.info[ 1 ] setText("^1Missile launch in");
	self.info[ 1 ].color = (0.0, 0.8, 0.0);
	self.info[ 1 ].fontscale = 1.4;
	self.info[ 1 ].archived = 0;
			
	self.info[ 2 ] = newClientHudElem( self );
	self.info[ 2 ].elemType = "font";
	self.info[ 2 ].x = 32;
	self.info[ 2 ].y = -45;
	self.info[ 2 ].alignX = "center";
	self.info[ 2 ].alignY = "bottom";
	self.info[ 2 ].horzAlign = "center";
	self.info[ 2 ].vertAlign = "bottom";
	self.info[ 2 ] setTimer( 10 );
	self.info[ 2 ].color = ( 1.0, 0.0, 0.0 );
	self.info[ 2 ].fontscale = 1.4;
	self.info[ 2 ].archived = 0;
	
	while( isDefined( level.flyingPlane ) && isDefined( self.info ) )
	{
		if( isDefined( level.missileLaunched ) && isDefined( self.info ) )
		{
			self.info[ 0 ] setText( "Press ^1[{+attack}] ^7to speed up ^1AGM missile" );
			self.info[ 1 ] setText( "^1Warhead explosion in" );
			self.info[ 2 ] setTimer( 10 );
			self.info[ 1 ].x = -38;
			self.info[ 2 ].x = 38;
			break;
		}
		wait .1;
	}
}

planeTimer()
{
	self endon( "disconnect" );
	level endon( "game_ended" );
	level endon( "flyOver" );
	
	timer = 40;
	
	while( timer > 0 )
	{
		wait .25;
		timer--;
		
		if( timer == 0 )
		{
			self thread launchMissile();
		}
		else if( isDefined( level.missileLaunched ) )
			break;
	}
	
	wait 10;
	
	thread endHardpoint();
}

launcher()
{
	self endon( "disconnect" );
	level endon( "game_ended" );
	level endon( "flyOver" );
	
	wait .5;

	while( isDefined( level.flyingPlane ) && !isDefined( level.missileLaunched ) )
	{
		if( self attackButtonPressed() )
		{
			self thread launchMissile();
			break;
		}
		wait .05;
	}
}

launchMissile()
{
	self endon( "disconnect" );
	level endon( "game_ended" );
	level endon( "flyOver" );
	
	level.AGMLaunchTime[ self getEntityNumber() ] = getTime();
	level.missileLaunched = true;
	
	self setClientDvar( "cg_fovscale", "0.75" );

	level.plane[ "missile" ] = spawn( "script_model", self.origin );
	level.plane[ "missile" ] setModel( "projectile_hellfire_missile" );
	level.plane[ "missile" ] playSound( "weap_cobra_missile_fire" );

	self LinkTo( level.plane[ "missile" ] );
    earthquake( 2, 0.8, level.plane[ "missile" ].origin, 300 );
	
	waittillframeend;
	
	self hide();
	
	speed = 20;
	monitor = 1;
	
	wait .1;
	
	thread trailfx();
	
	waittillframeend;
	
	for( ;; )
	{
		if( monitor == 1 )
		{
			if( self attackButtonPressed() )
			{
				speed = 100;
				monitor = 0;
			}
			else if( speed > 60 )
			{
				speed = 60;
				monitor = 0;
			}
			else if( speed < 60 )
				speed += 0.5;
		}

		angles = self getPlayerAngles();
		if( angles[ 0 ] <= 30 )
			self setPlayerAngles( ( 30, angles[1], angles[2] ) );
			
		level.plane[ "missile" ].angles = angles;
		vector = anglesToForward( level.plane[ "missile" ].angles );
		forward = level.plane[ "missile" ].origin + ( vector[ 0 ] * speed, vector[ 1 ] * speed, vector[ 2 ] * speed );
		collision = bulletTrace( level.plane[ "missile" ].origin, forward, false, self );
		level.plane[ "missile" ] moveTo( forward, .05 );
		
		if( collision[ "surfacetype" ] != "default" && collision[ "fraction" ] < 1 ) 
		{
			level.missileLaunched = undefined;
			target = level.plane[ "missile" ].origin;
			self unlink();
			self setOrigin( self.oldPosition );
			level.AGMLaunchTime[ self getEntityNumber() ] = getTime() - level.AGMLaunchTime[ self getEntityNumber() ];
			wait .05;
			thread explodeAGM( target );
			wait .1;
			thread endHardpoint();
			break;
		}
		
		if( ( self.oldPosition[ 2 ] - 800 ) > level.plane[ "missile" ].origin[ 2 ] ) //in case missile goes under map
		{
			level.missileLaunched = undefined;
			target = level.plane[ "missile" ].origin;
			self unlink();
			self setOrigin( self.oldPosition );
			level.AGMLaunchTime[ self getEntityNumber() ] = getTime() - level.AGMLaunchTime[ self getEntityNumber() ];
			wait .05;
			thread explodeAGM( target );
			wait .1;
			thread endHardpoint();
			break;
		}
		
		wait .05;
	}
}

trailFX()
{
	self endon( "disconnect" );
	level endon( "game_ended" );
	level endon( "flyOver" );

	while( isDefined( level.missileLaunched ) )
	{
		playFxonTag( level.hardEffects[ "hellfireGeo" ], level.plane[ "missile" ], "tag_origin" );
		
		wait 2;
	}
}

explodeAGM( target )
{
	if( !isDefined( target ) && isDefined( level.plane ) && isDefined( level.plane[ "missile" ] ) )
		target = level.plane[ "missile" ].origin;

	if( isDefined( target ) )
	{
		thread playSoundinSpace( "exp_suitcase_bomb_main", target );
		PlayFX( level.hardEffects[ "tankerExp" ], target );
		
		ents = maps\mp\gametypes\_weapons::getDamageableents( target, 400 );
		for( i = 0; i < ents.size; i++ )
		{
			if ( !ents[ i ].isPlayer || isAlive( ents[ i ].entity ) )
			{
				if( !isDefined( ents[ i ] ) )
					continue;
				
				if( isPlayer( ents[ i ].entity ) )
					ents[ i ].entity.sWeaponForKillcam = "agm";

				ents[ i ] maps\mp\gametypes\_weapons::damageEnt(
																self, 
																self, 
																10000, 
																"MOD_PROJECTILE_SPLASH", 
																"artillery_mp", 
																target, 
																vectornormalize( target - ents[ i ].entity.origin ) 
																);
			}
		}
		
		earthquake( 3, 1.2, target, 700 );
	}

	if( isDefined( level.plane ) && isDefined( level.plane[ "missile" ] ) )
		level.plane[ "missile" ] delete();
}

endHardpoint()
{
	self endon( "disconnect" );
	level notify( "flyOver" );
	
	self.pers[ "lastAGMUse" ] = getTime();
	
	waittillframeend;
	
	level.missileLaunched = undefined;
	self.oldPosition = undefined;
	
	if( !level.dvar[ "old_hardpoints" ] )
		self thread code\hardpoints::moneyHud();
	
	waittillframeend;
	
	self thread restoreHP();
	self show();
	self enableWeapons();
	
	waittillframeend;
	
	if( isDefined( self.r ) ) 
	{
		for( k = 0; k < self.r.size; k++ )
			if( isDefined( self.r[ k ] ) )
				self.r[ k ] destroy();
	}
	
	self.r = undefined;
	
	if( isDefined( self.info ) )
	{
		for( i = 0; i < self.info.size; i++ )
			self.info[ i ] destroy();
	}
	
	self.info = undefined;
	
	waittillframeend;
	
	self thread restoreVisionSettings();
	
	waittillframeend;
	
	if( isDefined( self.targetMarker ) )
	{
		for( k = 0; k < self.targetMarker.size; k++ ) 
				self.targetMarker[ k ] destroy();
	}
	
	self.targetMarker = undefined;
	
	wait .1;
	
	level.flyingPlane = undefined;
	level notify( "flyOverDC" );
}