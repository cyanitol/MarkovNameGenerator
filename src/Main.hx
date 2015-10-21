package;

import haxe.ds.StringMap;
import js.Browser;
import js.html.Element;
import js.html.InputElement;
import js.html.SelectElement;
import js.nouislider.NoUiSlider;
import js.wNumb.WNumb;
import lycan.namegen.NameGenerator;
import lycan.util.EditDistanceMetrics;
import lycan.util.FileReader;
import lycan.util.PrefixTrie;

using lycan.util.StringExtensions;

class Main {
	private var generator:NameGenerator;
	private var duplicateTrie:PrefixTrie;
	
	private var trainingDataKey:String = "tolkienesque_forenames";
	private var numToGenerate:Int = 100;
	private var minLength:Int = 7;
	private var maxLength:Int = 10;
	private var order:Int = 3;
	private var prior:Float = 0.01;
	private var maxProcessingTime:Float = 500;
	private var startsWith:String = "a";
	private var endsWith:String = "";
	private var includes:String = "l";
	private var excludes:String = "z";
	private var similar:String = "alina";
	private var generateTrieVisualization:Bool = false;
	private var generateMarkovVisualization:Bool = false;
	private var markovVisualizationMinP:Float = 0.01;
	
	private var trainingDataElement:SelectElement;
	private var orderElement:Element;
	private var priorElement:Element;
	private var maxProcessingTimeElement:Element;
	private var generateTrieVisualizationElement:Element;
	private var generateMarkovVisualizationElement:Element;
	private var markovVisualizationPElement:Element;
	
	private var currentNamesElement:Element;
	private var generateElement:Element;
	
	private var lengthElement:InputElement;
	private var startsWithElement:InputElement;
	private var endsWithElement:InputElement;
	private var includesElement:InputElement;
	private var excludesElement:InputElement;
	private var similarElement:InputElement;
	
	private var trainingData:StringMap<Array<String>>;
	
	private var trieGraph:TrieForceGraph;
	private var markovGraph:MarkovGraph;
	
    private static function main():Void {
		var main = new Main();
	}
	
	private inline function new() {
		trainingData = new StringMap<Array<String>>();
		
		trainingData.set("us_forenames", FileReader.readFile("embed/usforenames.txt").split("\n"));
		trainingData.set("tolkienesque_forenames", FileReader.readFile("embed/tolkienesqueforenames.txt").split("\n"));
		trainingData.set("werewolf_forenames", FileReader.readFile("embed/werewolfforenames.txt").split("\n"));
		trainingData.set("romandeity_forenames", FileReader.readFile("embed/romandeityforenames.txt").split("\n"));
		trainingData.set("norsedeity_forenames", FileReader.readFile("embed/norsedeityforenames.txt").split("\n"));
		trainingData.set("swedish_forenames", FileReader.readFile("embed/swedishforenames.txt").split("\n"));
		trainingData.set("english_towns", FileReader.readFile("embed/englishtowns.txt").split("\n"));
		trainingData.set("theological_demons", FileReader.readFile("embed/theologicaldemons.txt").split("\n"));
		trainingData.set("scottish_surnames", FileReader.readFile("embed/scottishsurnames.txt").split("\n"));
		trainingData.set("irish_forenames", FileReader.readFile("embed/irishforenames.txt").split("\n"));
		trainingData.set("icelandic_forenames", FileReader.readFile("embed/icelandicforenames.txt").split("\n"));
		trainingData.set("theological_angels", FileReader.readFile("embed/theologicalangels.txt").split("\n"));
		trainingData.set("japanese_forenames", FileReader.readFile("embed/japaneseforenames.txt").split("\n"));
		trainingData.set("french_forenames", FileReader.readFile("embed/frenchforenames.txt").split("\n"));
		trainingData.set("german_towns", FileReader.readFile("embed/germantowns.txt").split("\n"));
		trainingData.set("animals", FileReader.readFile("embed/animals.txt").split("\n"));
		trainingData.set("pokemon", FileReader.readFile("embed/pokemon.txt").split("\n"));
		
		//trainingData.set("profanity_filter", FileReader.readFile("embed/profanityfilter.txt").split("\n")); // For reasons
		
		Browser.window.onload = onWindowLoaded;
	}
	
	private inline function onWindowLoaded():Void {
		trainingDataElement = cast Browser.document.getElementById("trainingdatalist");
		
		orderElement = cast Browser.document.getElementById("order");		
		priorElement = cast Browser.document.getElementById("prior");
		maxProcessingTimeElement = cast Browser.document.getElementById("maxtime");
		
		NoUiSlider.create(orderElement, {
			start: [ 3 ],
			connect: 'lower',
			range: {
				'min': [ 1, 1 ],
				'max': [ 9 ]
			},
			pips: {
				mode: 'range',
				density: 10,
			}
		});
		createTooltips(orderElement);
		untyped orderElement.noUiSlider.on(UiSliderEvent.CHANGE, function(values:Array<Float>, handle:Int, rawValues:Array<Float>):Void {
			order = Std.int(values[handle]);
		});
		untyped orderElement.noUiSlider.on(UiSliderEvent.UPDATE, function(values:Array<Float>, handle:Int, rawValues:Array<Float>):Void {
			updateTooltips(orderElement, handle, Std.int(values[handle]));
		});
		
		NoUiSlider.create(priorElement, {
			start: [ 0.01 ],
			connect: 'lower',
			range: {
				'min': 0.001,
				'50%': 0.15,
				'max': 0.3
			},
			pips: {
				mode: 'range',
				density: 10,
				format: new WNumb( {
					decimals: 2
				})
			}
		});
		createTooltips(priorElement);
		untyped priorElement.noUiSlider.on(UiSliderEvent.CHANGE, function(values:Array<Float>, handle:Int, rawValues:Array<Float>):Void {			
			prior = Std.parseFloat(untyped values[handle]);
		});
		untyped priorElement.noUiSlider.on(UiSliderEvent.UPDATE, function(values:Array<Float>, handle:Int, rawValues:Array<Float>):Void {
			updateTooltips(priorElement, handle, values[handle]);
		});
		
		NoUiSlider.create(maxProcessingTimeElement, {
			start: [ 500 ],
			connect: 'lower',
			range: {
				'min': 50,
				'max': 5000
			},
			pips: {
				mode: 'range',
				density: 10,
				format: new WNumb( {
					decimals: 0
				})
			}
		});
		createTooltips(maxProcessingTimeElement);
		untyped maxProcessingTimeElement.noUiSlider.on(UiSliderEvent.CHANGE, function(values:Array<Float>, handle:Int, rawValues:Array<Float>):Void {
			maxProcessingTime = Std.parseFloat(untyped values[handle]);
		});
		untyped maxProcessingTimeElement.noUiSlider.on(UiSliderEvent.UPDATE, function(values:Array<Float>, handle:Int, rawValues:Array<Float>):Void {
			updateTooltips(maxProcessingTimeElement, handle, Std.int(values[handle]));
		});
		
		currentNamesElement = cast Browser.document.getElementById("currentnames");
		generateElement = cast Browser.document.getElementById("generate");
		lengthElement = cast Browser.document.getElementById("minmaxlength");
		generateTrieVisualizationElement = cast Browser.document.getElementById("generatetriegraph");
		generateMarkovVisualizationElement = cast Browser.document.getElementById("generatemarkovgraph");
		markovVisualizationPElement = cast Browser.document.getElementById("markovp");
		
		NoUiSlider.create(lengthElement, {
			start: [ 4, 11 ],
			connect: true,
			range: {
				'min': [ 3, 1 ],
				'max': 18
			},
			pips: {
				mode: 'range',
				density: 10,
			}
		});
		createTooltips(lengthElement);
		untyped lengthElement.noUiSlider.on(UiSliderEvent.CHANGE, function(values:Array<Float>, handle:Int, rawValues:Array<Float>):Void {
			if (handle == 0) {
				minLength = Std.int(values[handle]);
			} else if (handle == 1) {
				maxLength = Std.int(values[handle]);
			}
		});
		untyped lengthElement.noUiSlider.on(UiSliderEvent.UPDATE, function(values:Array<Float>, handle:Int, rawValues:Array<Float>):Void {
			updateTooltips(lengthElement, handle, Std.int(values[handle]));
		});
		
		/*
		NoUiSlider.create(generateTrieVisualizationElement, {
			orientation: "vertical",
			connect: 'lower',
			start: generateTrieVisualization ? 1 : 0,
			range: {
				'min': [0, 1],
				'max': 1
			},
			format: new WNumb( {
				decimals: 0
			})
		});
		untyped generateTrieVisualizationElement.noUiSlider.on(UiSliderEvent.CHANGE, function(values:Array<Float>, handle:Int, rawValues:Array<Float>):Void {
			generateTrieVisualization = Std.int(values[handle]) == 1 ? true : false;
		});
		
		
		NoUiSlider.create(generateMarkovVisualizationElement, {
			orientation: "vertical",
			connect: 'lower',
			start: 1,
			range: {
				'min': [0, 1],
				'max': 1
			},
			format: new WNumb( {
				decimals: 0
			})
		});
		untyped generateMarkovVisualizationElement.noUiSlider.on(UiSliderEvent.CHANGE, function(values:Array<Float>, handle:Int, rawValues:Array<Float>):Void {
			generateMarkovVisualization = Std.int(values[handle]) == 1 ? true : false;
		});
		
		NoUiSlider.create(markovVisualizationPElement, {
			connect: 'lower',
			start: 0.01,
			range: {
				'min': [0.001, 0.001],
				'max': 1
			},
			format: new WNumb( {
				decimals: 4
			}),
			pips: {
				mode: 'range',
				density: 10,
			}
		});
		createTooltips(markovVisualizationPElement);
		untyped markovVisualizationPElement.noUiSlider.on(UiSliderEvent.CHANGE, function(values:Array<Float>, handle:Int, rawValues:Array<Float>):Void {
			markovVisualizationMinP = values[handle];
		});
		untyped markovVisualizationPElement.noUiSlider.on(UiSliderEvent.UPDATE, function(values:Array<Float>, handle:Int, rawValues:Array<Float>):Void {
			updateTooltips(markovVisualizationPElement, handle, values[handle]);
		});
		*/
		
		startsWithElement = cast Browser.document.getElementById("startswith");
		endsWithElement = cast Browser.document.getElementById("endswith");
		includesElement = cast Browser.document.getElementById("includes");
		excludesElement = cast Browser.document.getElementById("excludes");
		similarElement = cast Browser.document.getElementById("similar");
		
		setDefaults();
		
		trainingDataElement.addEventListener("change", function() {
			if (trainingDataElement.value != null) {
				trainingDataKey = trainingDataElement.value;
			}
		}, false);
		
		generateElement.addEventListener("click", function() {
			var data = trainingData.get(trainingDataKey);
			Sure.sure(data != null);
			
			generate(data);
		}, false);
		
		startsWithElement.addEventListener("change", function() {
			if (startsWithElement.value != null) {
				startsWith = startsWithElement.value;
			}
		}, false);
		
		endsWithElement.addEventListener("change", function() {
			if (endsWithElement.value != null) {
				endsWith = endsWithElement.value;
			}
		}, false);
		
		includesElement.addEventListener("change", function() {
			if (includesElement.value != null) {
				includes = includesElement.value;
			}
		}, false);
		
		excludesElement.addEventListener("change", function() {
			if (excludesElement.value != null) {
				excludes = excludesElement.value;
			}
		}, false);
		
		similarElement.addEventListener("change", function() {
			if (similarElement.value != null) {
				similar = similarElement.value;
			}
		}, false);
		
		//js.Browser.window.setInterval(function() {
		//	d3trie.update();
		//}, 250);
	}
	
	private function createTooltips(slider:Element):Void {
		var tipHandles = slider.getElementsByClassName("noUi-handle");
		for (i in 0...tipHandles.length) {
			var div = js.Browser.document.createElement('div');
			div.className += "tooltip";
			tipHandles[i].appendChild(div);
			updateTooltips(slider, i, 0);
		}
	}
	
	private function updateTooltips(slider:Element, handleIdx:Int, value:Float):Void {
		var tipHandles = slider.getElementsByClassName("noUi-handle");
		tipHandles[handleIdx].innerHTML = "<span class='tooltip'>" + Std.string(value) + "</span>";
	}
	
	private function generate(data:Array<String>):Void {
		duplicateTrie = new PrefixTrie();
		for (name in data) {
			duplicateTrie.insert(name);
		}
		
		generator = new NameGenerator(data, order, prior);
		var names = new Array<String>();
		var startTime = Date.now().getTime();
		var currentTime = Date.now().getTime();
		
		while (names.length < numToGenerate && currentTime < startTime + maxProcessingTime) {
			var name = generator.generateName(minLength, maxLength, startsWith, endsWith, includes, excludes);
			if (name != null && !duplicateTrie.find(name)) {
				names.push(name);
				duplicateTrie.insert(name);
			}
			currentTime = Date.now().getTime();
		}
		
		appendNames(names);
		
		/*
		if(generateTrieVisualization) {
			trieGraph = new TrieForceGraph(duplicateTrie, "#triegraph", 400, 500);
		} else {
			D3.select("svg").remove();
		}
		
		if (generateMarkovVisualization) {
			markovGraph = new MarkovGraph(generator, 1, "#markovgraph", 400, 500, markovVisualizationMinP);
		} else {
			D3.select("svg").remove();
		}
		*/
	}
	
	private function appendNames(names:Array<String>):Void {
		if(similar.length > 0) {
			names.sort(function(x:String, y:String):Int {
				var xSimilarity:Float = EditDistanceMetrics.damerauLevenshtein(x, similar);
				var ySimilarity:Float = EditDistanceMetrics.damerauLevenshtein(y, similar);
				
				if (xSimilarity > ySimilarity) {
					return 1;
				} else if (xSimilarity < ySimilarity) {
					return -1;
				} else {
					return 0;
				}
			});
		}
		
		currentNamesElement.innerHTML = "";
		if (names.length == 0) {
			var li = Browser.document.createLIElement();
			li.textContent = "No names found";
			currentNamesElement.appendChild(li);
		}
		
		for (name in names) {
			var li = Browser.document.createLIElement();
			li.textContent = name.capitalize();
			currentNamesElement.appendChild(li);
		}
	}
	
	private function setDefaults():Void {
		numToGenerate = 100;	
		
		minLength = 7;
		maxLength = 10;
		
		order = 3;
		prior = 0.01;
		
		markovVisualizationMinP = 0.01;
		
		startsWith = "a";
		startsWithElement.value = startsWith;
		
		endsWith = "";
		endsWithElement.value = endsWith;
		
		includes = "l";
		includesElement.value = includes;
		
		excludes = "z";
		excludesElement.value = excludes;
		
		similar = "alina";
		similarElement.value = similar;
		
		generateTrieVisualization = false;
		generateMarkovVisualization = false;
	}
}