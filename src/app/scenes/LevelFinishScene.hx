package app.scenes;

import haxe.ui.toolkit.core.interfaces.IDisplayObjectContainer;
import haxe.ui.toolkit.core.PopupManager;
import haxe.ui.toolkit.core.RootManager;
import haxe.ui.toolkit.core.Toolkit;
import haxe.ui.toolkit.controls.Text;
import haxe.ui.toolkit.controls.Button;
import haxe.ui.toolkit.controls.Image;
import haxe.ui.toolkit.events.UIEvent;

import app.scenes.WindowScene;
import app.scenes.LevelMenuScene;
import app.scenes.LevelOpeningScene;
import app.entities.Level;
import app.Configuration;

/*
    Wird angezeigt, wenn ein Level beendet wurde.
    Das Level kann mit guten, sehr guten oder perfekten Zeiten bestanden werden,
    oder gar nicht.
*/
class LevelFinishScene extends WindowScene {

    private var configuration: Configuration;

    public function new(level: Level, _result: Result) {

        //Grundeinstellungen festlegen
        width = 400;
        height = 300;
        
        super();


        //Layout laden
        view = Toolkit.processXmlResource("assets/ui/layout/level-finish.xml");

            //Ergebniss anzeigen
        switch (_result) {
            case Result.Fail:
                view.findChild("result", Text, true).text = "Zu langsam!";
                view.findChild("icon", Image, true).resource = "assets/ui/result_fail.png";
            case Result.Bronze:
                view.findChild("result", Text, true).text = "Geschafft!";
                view.findChild("icon", Image, true).resource = "assets/ui/result_bronze.png";
            case Result.Silver:
                view.findChild("result", Text, true).text = "Gute Zeit!";
                view.findChild("icon", Image, true).resource = "assets/ui/result_silver.png";
            case Result.Gold:
                view.findChild("result", Text, true).text = "Herausragend!";
                view.findChild("icon", Image, true).resource = "assets/ui/result_gold.png";

        }

        //"Weiter"-Button sperren, wenn Level nicht geschafft wurde
        view.findChild("continue", Button, true).disabled = (_result == Result.Fail);



        //Buttonevents festlegen
        view.findChild("restart", Button, true).onClick = function(e:UIEvent){   new GameScene(level.id).show();    };
        view.findChild("continue", Button, true).onClick = function(e:UIEvent) {    

            this.configuration = new Configuration();

            //Prüfen, ob das Spiel besiegt wurde
            if (configuration.LEVEL == configuration.TOTALLEVELS) {
                //Wenn besiegt, Game-Beaten-Scene anzeigen
                new app.scenes.GameBeatenScene().show();
            } else {
                //Wenn nicht besiegt, normales Menü anzeigen
                 new LevelMenuScene().show();
            }

        };

    }

}