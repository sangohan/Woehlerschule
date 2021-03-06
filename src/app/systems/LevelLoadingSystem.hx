package app.systems;

import haxe.xml.Fast;

import ash.core.System;
import ash.core.NodeList;
import ash.core.Engine;
import ash.core.Entity;
import ash.signals.Signal1;
import openfl.Assets;

import app.math.Vector2;
import app.entities.Level;
import app.nodes.RenderNode;
import app.components.GameState;

import haxe.ui.toolkit.core.interfaces.IDisplayObjectContainer;
import haxe.ui.toolkit.core.Toolkit;

/*
    Läd zu Beginn des Spiels die Entitäten eines Level.
*/
class LevelLoadingSystem extends System {

    private var renderNodes: NodeList<RenderNode>;
    private var engine: Engine;
    private var level: Null<Level>; //Levelinformationen
    private var data: Fast; //Xml-Datei, die Entitäten speichert

    private var events: SystemEvents;

    public function new(events: SystemEvents) {
        super();

        this.events = events;
        this.level = null;

        //Events registrieren
        events.LOAD_LEVEL.add(onLoadLevel);
    }




    //Wird aufgerufen, wenn ein neues Level geladen werden soll.
    private function onLoadLevel(level: Level) : Void {

        clearLevel();

        //Aktuelles Level festlegen
        this.level = level;

        //Ein Entity erstellen, das das Spiel repräsentiert
        engine.addEntity( new Entity().add(new GameState()) );

        //Level parsen
        parseLevel(Xml.parse( Assets.getText("assets/levels/level" + level.id + ".xml") ));

        //Loaded-Level Event auslösen
        events.LOADED_LEVEL.dispatch(level);

    }

    //Level-Datei lesen und Entities erstellen
    private function parseLevel(xml: Xml) : Void {

        //Xml-Dokument auslesen
        data = new Fast(xml.firstElement());

        //Zuerst generelle Informationen auslesen und im Level-Objekt speichern
        for (property in data.node.CustomProperties.nodes.Property) {
            if (property.att.Name == "name") level.name = property.node.string.innerData;
            if (property.att.Name == "description") level.description = property.node.string.innerData;
            if (property.att.Name == "time") level.time = Std.parseInt(property.node.string.innerData);
        }

        //Durch alle Ebenen durchgehen und Entitäten laden
        for (layer in data.node.Layers.nodes.Layer) {
            for (item in layer.node.Items.nodes.Item) {
                parseItem(item);
            }
        }

    }


    private function parseItem(item: Fast) : Void {

        var type: String = "";

        //Typ des Entities herausfinden
        for (property in item.node.CustomProperties.nodes.Property) {
            if (property.att.Name == "type") type = property.node.string.innerData;
        }

        //Je nach Typ ein Objekt der Entität erstellen und der Engine mitteilen.
        switch type {
            case "grass-ground": engine.addEntity( new app.entities.Grass(parsePolygon(item, true)) );
            case "car": engine.addEntity( new app.entities.Car(parsePosition(item), parseRotation(item)) );
            case "road": parseRoad(item);
            case "finish": engine.addEntity( new app.entities.Finish(parsePosition(item), parseScale(item), parseRotation(item)) );
            case "checkpoint": engine.addEntity( new app.entities.Checkpoint(parsePosition(item), parseScale(item), parseRotation(item)) );
            case "barrier": engine.addEntity( new app.entities.Barrier(parsePosition(item), parseScale(item), parseRotation(item)) );
            case "box": engine.addEntity( new app.entities.Box(parsePosition(item), parseScale(item), parseRotation(item)) );
            case "tree": engine.addEntity( new app.entities.Tree(parsePosition(item), parseScale(item), parseRotation(item)) );
            case "boost": engine.addEntity( new app.entities.Boost(parsePosition(item), parseScale(item), parseRotation(item)) );
            case "infobox": engine.addEntity( new app.entities.Infobox(parsePosition(item), parseScale(item), parseRotation(item), parseView(item)) );
            case "path": engine.addEntity( new app.entities.Path(parseTarget(item), parsePolygon(item, true)[0], parsePolygon(item, true)[1]) );
            default: throw "Error while loading level: Unknow Entity of type '" + type + "'";
        }


    }

    //Höhe und Breite auslesen
    private function parseScale(item: Fast) : Vector2 {

        var x: Float = Std.parseFloat(item.node.Scale.node.X.innerData),
            y: Float = Std.parseFloat(item.node.Scale.node.Y.innerData);

        return new Vector2(x,y);
    }

    //Rotation auslesen (von Bogenmaß in Grad)
    private function parseRotation(item: Fast) : Float {
        return Std.parseFloat(item.node.Rotation.innerData) *(180/Math.PI);
    }

    //UI-Element auslesen (für Infobox)
    private function parseView(item: Fast) : IDisplayObjectContainer {
        for (property in item.node.CustomProperties.nodes.Property) {
            if (property.att.Name == "view") return Toolkit.processXml(Xml.parse(StringTools.htmlUnescape(property.node.string.innerData)));
        }

        throw "Error while loading level: Infobox has no view property";
        return null;
    }

    //X- und Y-Position auslesen
    private function parsePosition(item: Fast) : Vector2 {

        var x: Float = Std.parseFloat(item.node.Position.node.X.innerData),
            y: Float = Std.parseFloat(item.node.Position.node.Y.innerData);

        return new Vector2(x,y);
    }


    //Ziel-Entität auslesen (für Animationspfad)
    private function parseTarget(item: Fast) : Entity {
        /*
            Für eine Animation gibt es eine Pfad-Entität und eine Ziel-Entität, die sich auf dem 
            Pfad bewegt.
            In der Leveldatei ist in jeder Pfad-Entität der Name der Ziel-Entität gespeichert. 
        */

        var targetName: String = "";

        //Name des Ziels aus der Pfad-Entität auslesen
        for (property in item.node.CustomProperties.nodes.Property) {
            if (property.att.Name == "target") targetName = property.innerData;
        }

        

        var targetPosition: Vector2 = new Vector2(0,0);

        //Danach in der ganzen Datei nach der Ziel-Entität mit eben diesem Namen suchen
        for (layer in data.node.Layers.nodes.Layer) {
            for (item in layer.node.Items.nodes.Item) {

                //Prüfen, ob es sich beim aktuellen Item um den target handelt.
                if (item.att.Name == targetName) targetPosition = parsePosition(item);

            }
        }


        var target: Entity = null;

        //Zuletzt mit Hilfe der Position eine Referenz zum entsprechendem Entity bekommen
        for (positionNode in renderNodes) {
            if (positionNode.position.vector == targetPosition) target = positionNode.entity;
        }

        return target;
    }

    private function parsePolygon(item: Fast, absolute: Bool = false) : Array<Vector2> {

        var polygon: Array<Vector2> = new Array<Vector2>();

        //Sollen die Punkte absolut oder relativ zum Mittelpunkt des Entities ausgelesen werden?
        if (absolute) {
            for (point in item.node.WorldPoints.nodes.Vector2)
                polygon.push(new Vector2(Std.parseFloat(point.node.X.innerData), Std.parseFloat(point.node.Y.innerData)));
        
        } else {
            for (point in item.node.LocalPoints.nodes.Vector2)
                polygon.push(new Vector2(Std.parseFloat(point.node.X.innerData), Std.parseFloat(point.node.Y.innerData)));

        }

        return polygon;
    }

    private function parseRoad(item: Fast) : Void {
        

        var width: Float = Std.parseFloat(item.node.LineWidth.innerData) / 2,
            waypoints: Array<Vector2> = parsePolygon(item, true);

        //Error werfen, wenn Strecke nur einen Wegpunkt hat.
        if (waypoints.length < 2) throw "Level-Loading failed: Road has only one waypoint.";

        for ( i in 0...waypoints.length-1 ) {
    
            var start: Vector2 = waypoints[i],
                end: Vector2 = waypoints[i+1];

            var startAngle: Float = (i==0) ? start.angleTo(end) : (start.angleTo(end) + new Vector2(waypoints[i-1].x, waypoints[i-1].y).angleTo(start)) / 2,
                endAngle: Float = (i==waypoints.length-2) ? start.angleTo(end) : (start.angleTo(end) + end.angleTo(new Vector2(waypoints[i+2].x, waypoints[i+2].y))) / 2;


            engine.addEntity( new app.entities.Road(start,  end, startAngle, endAngle, width) );

        }


    }


    //Alle alten Entities löschen
    private function clearLevel() : Void {

        var entitiesToBeRemoved: Array<Entity> = new Array<Entity>();

        for (entity in engine.entities) {
            entitiesToBeRemoved.push(entity);
        }

        for (entity in entitiesToBeRemoved) {
            engine.removeEntity(entity);
        }

    }

    //Wird aufgerufen, wenn System der Engine hinzugefügt wird
    public override function addToEngine(engine: Engine):Void {
        renderNodes = engine.getNodeList(RenderNode);
        this.engine = engine;
    }

    //Wird aufgerufen, wenn System von der Engine entfernt wird
    public override function removeFromEngine(engine: Engine):Void {
        renderNodes = null;
    }


}