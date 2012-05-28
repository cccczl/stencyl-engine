package com.stencyl.io;

import haxe.xml.Fast;
import com.stencyl.utils.Utils;

import com.stencyl.models.Resource;
import com.stencyl.models.actor.Sprite;
import com.stencyl.models.actor.Animation;

import box2D.common.math.B2Vec2;
import box2D.dynamics.B2FixtureDef;
import box2D.collision.B2AABB;
import box2D.common.math.B2Transform;
import box2D.collision.shapes.B2Shape;
import box2D.collision.shapes.B2CircleShape;
import box2D.collision.shapes.B2EdgeShape;
import box2D.collision.shapes.B2PolygonShape;

class SpriteReader implements AbstractReader
{
	public function new() 
	{
	}		

	public function accepts(type:String):Bool
	{
		return type == "sprite";
	}
	
	public function read(ID:Int, type:String, name:String, xml:Fast):Resource
	{
		//trace("Reading Sprite (" + ID + ") - " + name);
		
		var width:Int = Std.parseInt(xml.att.width);
		var height:Int = Std.parseInt(xml.att.height);
		var defaultAnimation:Int = 0;
		
		try
		{
			defaultAnimation = Std.parseInt(xml.att.defaultAnimation);
		}
		
		catch(e:String)
		{
		}
		
		var animations:Array<Animation> = new Array<Animation>();
		var sprite:Sprite = new Sprite(ID, name, width, height, defaultAnimation);
		
		for(e in xml.elements)
		{
			sprite.animations.set(Std.parseInt(e.att.id), readAnimation(e, sprite));
		}

		return sprite;
	}
	
	public function readAnimation(xml:Fast, parent:Sprite):Animation
	{
		var animID:Int = Std.parseInt(xml.att.id);
		var animName:String = xml.att.name;
			
		var imgWidth:Int = Std.parseInt(xml.att.width);
		var imgHeight:Int = Std.parseInt(xml.att.height);
		
		var originX:Float = Std.parseFloat(xml.att.originx);
		var originY:Float = Std.parseFloat(xml.att.originy);
		
		var framesAcross:Int = Std.parseInt(xml.att.across);
		var framesDown:Int = Std.parseInt(xml.att.down);
		
		var parentID:Int = parent.ID;
		var shapes = readShapes(xml, imgWidth/framesAcross, imgHeight/framesDown);
		var looping:Bool = Utils.toBoolean(xml.att.loop);
		var imgData:Dynamic = Data.get().resourceAssets.get(parentID + "-" + animID + ".png");
		var durations:Array<Int> = new Array<Int>();
		var counter:Int = 0;
		
		var s:String = xml.att.durations;
		var frames:Array<String> = s.split(",");
		
		for(f in frames)
		{
			//Round to the nearest 10ms - there's no more granularity than this and makes it much easier for me.
			durations[counter] = Std.parseInt(f);
			
			durations[counter] = Math.floor(durations[counter] / 10);
			durations[counter] *= 10;
			
			counter++;
		}

		return new Animation
		(
			animID,
			animName,
			parentID, 
			shapes, 
			looping, 
			imgData,
			imgWidth,
			imgHeight,
			originX,
			originY,
			durations, 
			framesAcross, 
			framesDown
		);
	}
	
	public function readShapes(xml:Fast, imgWidth:Float, imgHeight:Float):IntHash<B2FixtureDef>
	{
		var shapes = new IntHash<B2FixtureDef>();
		
		for(e in xml.elements)
		{
			var shapeID = Std.parseInt(e.att.id);
			var groupID = Std.parseInt(e.att.gid);
			
			var shapeType:String = e.name;
			var shapeParams:Array<String> = e.att.data.split(",");
			var shape = createShape(shapeType, shapeParams, 0, 0, imgWidth, imgHeight);
			
			var fixtureDef = new B2FixtureDef();
			fixtureDef.shape = shape;
			
			fixtureDef.density = Std.parseFloat(e.att.density);

			//These have no effect.
			fixtureDef.friction = Std.parseFloat(e.att.fric);
			fixtureDef.restitution = Std.parseFloat(e.att.rest);
			
			fixtureDef.isSensor = Utils.toBoolean(e.att.sensor);
			fixtureDef.groupID = Std.parseInt(e.att.gid);
			
			shapes.set(shapeID, fixtureDef);
		}
		
		return shapes;
	}
	
	public static function createShape(type:String, params:Array<String>, xOffset:Float=0, yOffset:Float=0, imgWidth:Float=-1, imgHeight:Float=-1):Dynamic
	{
		var x:Float = 0;
		var y:Float = 0;
		var w:Float = 0;
		var h:Float = 0;
		
		if(type == "circle")
		{
			var radius = Std.parseFloat(params[0]);
			x = Std.parseFloat(params[1]);
			y = Std.parseFloat(params[2]);
			
			var diameter = radius * 2;
			
			var c = new B2CircleShape();
			c.m_radius = Engine.toPhysicalUnits(radius);
			c.m_p.x = Engine.toPhysicalUnits(x - (imgWidth - diameter)/2);
			c.m_p.y = Engine.toPhysicalUnits(y - (imgHeight - diameter)/2);
			
			return c;
		}
		
		else if(type == "poly" || type == "polyregion")
		{			
			var vertices = new Array<B2Vec2>();
			
			var numVertices:Int = Std.parseInt(params[0]);
			var vIndex:Int = 0;
			var i:Int = 1;
			
			
			var x0:Float = 0;
			var y0:Float = 0;
			
			if(type == "polyregion")
			{
				x0 = 10000000;
				y0 = 10000000;
			}
			
			var x1:Float = 0;
			var y1:Float = 0;
			
			while(vIndex < numVertices)
			{
				x = Engine.toPhysicalUnits(Std.parseFloat(params[i]));
				y = Engine.toPhysicalUnits(Std.parseFloat(params[i + 1]));
				
				x0 = Math.min(x0, Std.parseFloat(params[i]));
				y0 = Math.min(y0, Std.parseFloat(params[i + 1]));
				x1 = Math.max(x1, Std.parseFloat(params[i]));
				y1 = Math.max(y1, Std.parseFloat(params[i + 1]));
				
				vertices[vIndex] = new B2Vec2(x, y);
				vIndex++;
				i += 2;
			}
											
			EnsureCorrectVertexDirection(vertices);
							
			w = x1 - x0;
			h = y1 - y0;
			
			var xDiff:Float = x0 - Engine.toPixelUnits(xOffset);
			var yDiff:Float = y0 - Engine.toPixelUnits(yOffset);

			var hw:Float = w/2;
			var hh:Float = h/2;

			//Axis-orient the polygon otherwise it rotates around the wrong point.
			var s = B2PolygonShape.asArray(vertices, vertices.length);

			var aabb = new B2AABB();
			var t = new B2Transform();
			t.setIdentity();
			s.computeAABB(aabb, t); 
						
			//Account for origin and subtract by half the difference.
			if(w < imgWidth)
			{	
				if(type ==  "polyregion") x0 += Math.abs(imgWidth - w) / 2;
				else x0 += Engine.toPhysicalUnits(Math.abs(imgWidth - w) / 2);
			}
			
			if(h < imgHeight)
			{
				if(type == "polyregion") y0 += Math.abs(imgHeight - h) / 2;
				else y0 += Engine.toPhysicalUnits(Math.abs(imgHeight - h) / 2);
			}
			
			//Reconstruct a new polygon that's axis-oriented.
			vIndex = 0;
			i = 1;

			while(vIndex < numVertices)
			{
				if (type == "polyregion")
				{
					var vX:Float = Engine.toPhysicalUnits(Std.parseFloat(params[i]) - hw - x0 + xDiff);
					var vY:Float = Engine.toPhysicalUnits(Std.parseFloat(params[i + 1]) - hh  - y0 + yDiff);
					vertices[vIndex] = new B2Vec2(vX, vY);
				}
				
				else
				{
					vertices[vIndex] = new B2Vec2(Engine.toPhysicalUnits(Std.parseFloat(params[i]) - hw) - x0, 
					                              Engine.toPhysicalUnits(Std.parseFloat(params[i + 1]) - hh) - y0);
				}						  

				vIndex++;
				i += 2;
			}

			EnsureCorrectVertexDirection(vertices);			

			return B2PolygonShape.asArray(vertices, vertices.length);
		}
		
		else if(type == "wireframe")
		{
			var vertices:Array<B2Vec2> = new Array<B2Vec2>();
			
			var numVertices2 = Std.parseFloat(params[0]);
			var vIndex2 = 0;
			var i2 = 1;
			
			while(vIndex2 < numVertices2)
			{
				vertices.push(new B2Vec2(Engine.toPhysicalUnits(Std.parseFloat(params[i2])), Engine.toPhysicalUnits(Std.parseFloat(params[i2 + 1]))));
				vIndex2++;
				i2 += 2;
			}
			
			w = getWidth(vertices);
			h = getHeight(vertices);
			
			var arr = new Array<Dynamic>();

			for(i in 0...vertices.length + 1)
			{
				var poly = B2PolygonShape.asEdge(vertices[i%vertices.length], vertices[(i+1)%vertices.length]);
				arr.push(poly);
			}
			
			var toReturn = new IntHash<Dynamic>();
			toReturn.set(0, arr);
			toReturn.set(1, w);
			toReturn.set(2, h);
			
			return toReturn;				
		}
		
		return null;
	}
	
	/*public static function decomposeShape(params:Array):Vector.<b2PolygonShape>
	{
		var vlist:Vector.<Number> = new Vector.<Number>();
		var numVertices:Number = params[0];
		var vIndex:Number = 0;
		var i:Number = 0;
			
		while(vIndex < numVertices)
		{			
			vlist[i] = params[i+1];
		    vlist[i + 1] = params[i + 2];
			vIndex++;
			i += 2;
		}

		var pshapes:Vector.<b2PolygonShape> = b2PolygonShape.Decompose(vlist);
		
		return pshapes;
	}*/
	
	/// Check the orientation of vertices. If they are in the wrong direction, flip them. Returns true if the vertecies need to be flipped.
	public static function CheckVertexDirection(v:Array<B2Vec2>):Bool {
		if(v.length > 2) {
			var wind:Float = 0;
			var i:Int = 0;
			while(wind == 0 && i < (v.length - 2)) {
				wind = v[i].winding(v[i + 1], v[i + 2]);
				++i;
			}
			if(wind < 0) {
				return false;
			}
		}
		return true;
	}
	
	/// If the vertices are in the wrong direction, flips them. Returns true if they were ok to start with, false if they were flipped.
	public static function EnsureCorrectVertexDirection(v:Array<B2Vec2>):Bool {
		if(!CheckVertexDirection(v)) {
			ReverseVertices(v);
			return false;
		}
		return true;
	}
	
	/// Reverses the direction of a V2 vector.
	public static function ReverseVertices(v:Array<B2Vec2>) {
		var low:Int = 0;
		var high:Int = v.length - 1;
		var tmp:Float;
		while(high > low) {
			tmp = v[low].x;
			v[low].x = v[high].x;
			v[high].x = tmp;
			tmp = v[low].y;
			v[low].y = v[high].y;
			v[high].y = tmp;
			++low;
			--high;
		}			
	}
		
	public static function getWidth(vertices:Array<B2Vec2>):Float
	{
		var minX:Float = 10000000;
		var maxX:Float = 0;
		
		for(v in vertices)
		{
			minX = Math.min(minX, v.x);
			maxX = Math.max(maxX, v.x);
		}
		
		return maxX - minX;
	}
	
	public static function getHeight(vertices:Array<B2Vec2>):Float
	{
		var minY:Float = 10000000;
		var maxY:Float = 0;
		
		for(v in vertices)
		{
			minY = Math.min(minY, v.y);
			maxY = Math.max(maxY, v.y);
		}
		
		return maxY - minY;
	}
}
