package com.stencyl.models.background;

import openfl.display.DisplayObject;
import openfl.display.Graphics;
import openfl.display.Bitmap;
import openfl.display.BitmapData;
import openfl.geom.Rectangle;
import openfl.geom.Point;

import com.stencyl.Engine;
import com.stencyl.models.scene.layers.BackgroundLayer;
import com.stencyl.utils.Assets;

class ImageBackground extends Resource implements Background 
{
	public var currFrame:Int;
	public var currTime:Float;
	
	public var img:BitmapData;
	public var frames:Array<Dynamic>;
	public var durations:Array<Int>;
	
	public var parallaxX:Float;
	public var parallaxY:Float;
	
	public var repeats:Bool;
	public var repeated:Bool;
	
	public var graphicsLoaded:Bool;
	
	public function new
	(
		ID:Int,
		atlasID:Int,
		name:String,
		durations:Array<Int>,
		parallaxX:Float,
		parallaxY:Float,
		repeats:Bool
	)
	{	
		super(ID, name, atlasID);
		
		this.parallaxX = parallaxX;
		this.parallaxY = parallaxY;
		this.durations = durations;
		this.repeats = repeats;
					
		this.currTime = 0;
		this.currFrame = 0;
		
		if(isAtlasActive())
		{
			loadGraphics();		
		}
		
		repeated = false;
	}	
	
	public function update()
	{
	}
	
	public function draw(g:Graphics, cameraX:Int, cameraY:Int, screenWidth:Int, screenHeight:Int)
	{
	}		
	
	//TODO: drawTiles on CPP
	public function drawRepeated(?bitmap:BackgroundLayer, screenWidth:Int, screenHeight:Int)
	{
		var tw:Float = img.width;
		var th:Float = img.height;
		var rect = new Rectangle(0, 0, tw, th);
		
		if (tw >= screenWidth && th >= screenHeight)
		{
			repeated = true;
			return;
		}
		
		//So it doesn't cutoff, extend width/height
		if (tw < screenWidth)
		{
			screenWidth += Std.int(tw) - (screenWidth % Std.int(tw));
		}
		
		if (th < screenHeight)
		{
			screenHeight += Std.int(th) - (screenHeight % Std.int(th));
		}

		var texture = new BitmapData(Std.int(Math.max(screenWidth, tw)), Std.int(Math.max(screenHeight, th)));
		
		for(yPos in 0...Std.int(screenHeight / th) + 1)
		{
			for(xPos in 0...Std.int(screenWidth / tw) + 1)
			{
				texture.copyPixels(img, rect, new Point(xPos * tw, yPos * th));
			}
		}
		
		//bitmap.setImage(texture);
		this.img = texture;
		
		repeated = true;
	}
	
	//For Atlases
	
	override public function loadGraphics()
	{
		if(graphicsLoaded)
			return;
		
		var frameData = new Array<Dynamic>();
		var numFrames = durations.length;
		
		if(numFrames > 0)
		{
			for(i in 0...numFrames)
			{
				frameData.push
				(
					Assets.getBitmapData
					(
						"assets/graphics/" + Engine.IMG_BASE + "/background-" + ID + "-" + i + ".png",
						false
					)
				);
			}
		}
		
		else
		{
			frameData.push
			(
				Assets.getBitmapData
				(
					"assets/graphics/" + Engine.IMG_BASE + "/background-" + ID + "-0.png",
					false
				)
			);
		}
		
		//---
	
		this.frames = new Array<Dynamic>();
		
		for(i in 0...frameData.length)
		{
			if(this.repeats)
			{
				this.img = frameData[i];
				drawRepeated(Std.int(Engine.screenWidth * Engine.SCALE), Std.int(Engine.screenHeight * Engine.SCALE));
				this.frames.push(this.img);
			} 
			else 
			{
				this.frames.push(frameData[i]);			
			}	
		
		}
		
		this.img = frames[0];
		
		graphicsLoaded = true;
	}
	
	override public function unloadGraphics()
	{
		if(!graphicsLoaded)
			return;
		
		//Replace with a 1x1 px blank - graceful fallback
		img = new BitmapData(1, 1);
		currFrame = 0;
		repeated = false;
		frames = [];
		
		for(d in durations)
		{
			frames.push(img);
		}
		
		//---
		
		var numFrames = durations.length;
		
		graphicsLoaded = false;
	}

	override public function reloadGraphics(subID:Int)
	{
		super.reloadGraphics(subID);
		for(layer in Engine.engine.backgroundLayers)
		{
			if(layer.model == this)
			{
				layer.reload(layer.resourceID);
			}
		}
	}
}
