package 
{
	import fastByteArray.FastByteArray;
	import flash.display.BitmapData;
	import flash.display.Sprite;
	import flash.display3D.Context3DTextureFormat;
	import flash.events.Event;
	import flash.events.TimerEvent;
	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;
	import flash.geom.Rectangle;
	import flash.net.FileFilter;
	import flash.utils.ByteArray;
	import flash.utils.Timer;
	import swfdata.atlas.BitmapSubTexture;
	import swfdata.atlas.BitmapTextureAtlas;
	import swfdata.atlas.GenomeTextureAtlas;
	import swfdata.dataTags.SwfPackerTag;
	import swfDataExporter.SwfExporter;
	import swfparser.SwfDataParser;
	import swfparser.SwfParserLight;
	import util.MaxRectPacker;
	import util.PackerRectangle;
	
	public class TestExporing extends Sprite 
	{
		private var fileName:String = "gem_mine";
		
		private var fileContent:ByteArray;
		private var swfDataParser:SwfDataParser;
		private var packedAtlas:BitmapTextureAtlas;
		private var maxRectPacker:MaxRectPacker = new MaxRectPacker(2048, 2048);
		private var data:FastByteArray = new FastByteArray(null, 1024*100000);
		private var swfExporter:SwfExporter;
		private var file:File;
		
		private var testScene:TestScene;
		
		public function TestExporing() 
		{
			super();
			
			file = File.documentsDirectory.resolvePath(fileName + ".swf");
			
			var t:Timer = new Timer(1000, 1);
			t.addEventListener(TimerEvent.TIMER_COMPLETE, onStartParse);
			t.start();
			//browseContetn();
		}
		
		private function quickHash(a:Number, b:Number):Number
		{
			return a + b * (a > b? a:b);
		}
		
		private function onStartParse(e:TimerEvent = null):void 
		{
			openAndLoadContent();
			parseSwfData();
			packRectangles();
			rebuildAtlas();
			packData();
			unpackData();
		}
		
		private function browseContetn():void 
		{
			file = new File("D:\panda\village\trunk-static\root\swf\actor\skin_summer\complex_decor");//File.applicationDirectory.clone();
			
			file.browseForOpen("Select animation file", [new FileFilter("swf file with animation", "*.swf", "*.swf")]);
			file.addEventListener(Event.SELECT, onSelected);
		}
		
		private function onSelected(e:Event):void 
		{
			onStartParse();
		}
		
		private function unpackData():void 
		{
			//swfDataParser.packerTags.length = 0;
			//data.position = 0;
			//var atlas:BitmapTextureAtlas = swfExporter.importSwf(data, swfDataParser.context.shapeLibrary, swfDataParser.packerTags);
			
			testScene = new TestScene();
			testScene.addEventListener(Event.COMPLETE, onGenomeReady);
			
			stage.addChild(testScene);
		}
		
		private function onGenomeReady(e:Event):void 
		{
			var swfParserLight:SwfParserLight = new SwfParserLight();
			var swfTags:Vector.<SwfPackerTag> = new Vector.<SwfPackerTag>;
			
			data.position = 0;
			
			var genomeTextureAtlas:GenomeTextureAtlas = swfExporter.importSwfGenome("noname", data, swfParserLight.context.shapeLibrary, swfTags, Context3DTextureFormat.BGRA);
			
			swfParserLight.context.library.addShapes(swfParserLight.context.shapeLibrary);
			swfParserLight.processDisplayObject(swfTags);
			
			
			testScene.show(swfParserLight.context.library, genomeTextureAtlas);
		}
		
		private function packData():void 
		{
			swfExporter = new SwfExporter();
			
			trace("### PACKED ATLAS ###");
			trace(packedAtlas.atlasData.width, packedAtlas.atlasData.height);
			swfExporter.exportSwf(packedAtlas, swfDataParser.context.shapeLibrary, swfDataParser.packerTags, data);
			
			var file:File = File.documentsDirectory.resolvePath(fileName + ".animation");
			var fileStream:FileStream = new FileStream();
			fileStream.open(file, FileMode.WRITE);
			
			fileContent = new ByteArray();
			fileStream.writeBytes(data.byteArray, 0, data.length);
			fileStream.close();
			
			//data.clear();
			swfDataParser.clear();
		}
		
		private function rebuildAtlas():void 
		{
			var atlasSoruce:BitmapData = maxRectPacker.drawAtlas(0);
			packedAtlas = new BitmapTextureAtlas(atlasSoruce.width, atlasSoruce.height, 4);
			packedAtlas.atlasData = atlasSoruce;
			
			var rects:Vector.<PackerRectangle> = maxRectPacker.atlasDatas[0].rectangles;
			
			
			for (var i:int = 0; i < rects.length; i++)
			{
				var currentRegion:PackerRectangle = rects[i];
				
				var region:Rectangle = new Rectangle();
				region.setTo(currentRegion.x, currentRegion.y, currentRegion.width, currentRegion.height);
				
				packedAtlas.createSubTexture(currentRegion.id, region, currentRegion.scaleX, currentRegion.scaleY);
			}
			
			//WindowUtil.openWindowToReview(packedAtlas.atlasData);
			
			maxRectPacker.clearData();
		}
		
		private function packRectangles():void 
		{
			var rectangles:Vector.<PackerRectangle> = new Vector.<PackerRectangle>;
			
			var atlas:BitmapTextureAtlas = swfDataParser.context.atlasDrawer.targetAtlas;
			//WindowUtil.openWindowToReview(atlas.atlasData, "default atlas");
			
			for(var regionName:int in atlas.subTextures)
			{
				var subTexture:BitmapSubTexture = atlas.subTextures[regionName];
				var region:Rectangle = subTexture.bounds;
				var packerRect:PackerRectangle = PackerRectangle.get(0, 0, region.width + atlas.padding * 2, region.height + atlas.padding * 2, subTexture.id, atlas.atlasData, region.x - atlas.padding, region.y - atlas.padding);
				packerRect.scaleX = subTexture.transform.scaleX;
				packerRect.scaleY = subTexture.transform.scaleY;
				
				rectangles.push(packerRect);
			}
			
			maxRectPacker.clearData();
			maxRectPacker.packRectangles(rectangles, 0, 2);		
		}
		
		private function parseSwfData():void 
		{
			swfDataParser = new SwfDataParser();
			swfDataParser.parseSwf(fileContent, true);
			fileContent.clear();
		}
		
		private function openAndLoadContent():void 
		{
			var fileStream:FileStream = new FileStream();
			fileStream.open(file, FileMode.READ);
			
			fileContent = new ByteArray();
			fileStream.readBytes(fileContent, 0, fileStream.bytesAvailable);
			fileStream.close();
		}
		
	}

}