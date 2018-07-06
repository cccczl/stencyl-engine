package com.stencyl.graphics.transitions;

import openfl.display.BitmapData;
import openfl.geom.ColorTransform;
import openfl.display.Shape;

import com.stencyl.Engine;

import motion.Actuate;
import motion.easing.Linear;

class FadeOutTransition extends Transition
{
	public var color:Int;
	public var rect:Shape;
	
	public function new(duration:Float, color:Int=0xff000000)
	{
		super(duration);
		
		this.color = color;
		this.direction = Transition.IN;
	}
	
	override public function start()
	{
		active = true;
		
		rect = new Shape();
		rect.alpha = 0;
		var g = rect.graphics;
		
		g.beginFill(color);
		g.drawRect(0, 0, Engine.screenWidth * Engine.SCALE + 4, Engine.screenHeight * Engine.SCALE + 4);
		g.endFill();
		
		g.drawCircle(1, 1, 1); //HACK: Force a software draw for this shape.
		
		Engine.engine.transitionLayer.addChild(rect);
		
		Actuate.tween(rect, duration, {alpha:1}).ease(Linear.easeNone).onComplete(stop);
	}
	
	override public function cleanup()
	{
		if(rect != null)
		{
			Engine.engine.transitionLayer.removeChild(rect);
			rect = null;
		}
	}
}