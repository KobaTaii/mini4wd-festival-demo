/**
 * @file   mini4wd_seed_demo.pde
 * @brief  AICHIPにコマンドを送りLEDの点灯状態,motorのduty比などをコントロールする <br>
 *         controlP5というライブラリを使用しているのでimportすること <br>
 *         メニューバーのSketch >Import Library > AddLibraryから追加が可能<br>
 *         Processing 2.2.1での動作推奨<br>
 *         Processing2.2.1にはExport機能で実行ファイルを出力してもSerial通信関係のライブラリが正常に機能しないバグがあり. <br>
 *
 * @author RTCorp. Ryota Takahashi, Tamagawa Univ Taiki Kobayashi
 */
/////////////////////////////
//各種importファイル
/////////////////////////////
import processing.serial.*;
import controlP5.*;           //Sketch >Import Library > AddLibraryから追加が可能

///////////////////////////////////////
//変数宣言
///////////////////////////////////////
ComPortConnection comp;
Serial port;

boolean flag_DISCONNECT_button_created = false;
boolean flag_CONNECT_button_created    = false;
String com_port;  

// ---add ---
int interval_time = 3000; // duty切り替え時間(ミリ秒)
int last_toggle_time = 0; // 最後にdutyを切り替えた時間
boolean is_duty_high = false; // 現在のdutyの状態 (false=30%, true=100%)

boolean is_running = false; // 走行中フラグ

String current_mode = "INTERVAL"; // 現在の動作モード

ControlP5 cp5; // グローバル変数に変更
//----------

/**
 * プログラム起動時に一度だけ呼ばれる処理
 *         <ul>
 *          <li>ボタン等のUIを使用するためのクラス </li>
 *          <li>画面等の初期化 </li>
 *         </ul>
 *
 * @param void
 * @return void
 */
void setup() 
{
  //画面等の初期化
  background(0);
  frameRate(60);
  PFont pfont = createFont("Arial", 20, true); 
  ControlFont font = new ControlFont(pfont, 241);
  textSize(20);
  size(500, 300);

  //ボタン等のUIを使用するためのクラス
  cp5 = new ControlP5(this); // グローバル変数を初期化
  comp  = new ComPortConnection(20, 20, "COM7", cp5);  
  
//STARTボタン
   cp5.addButton("START")
        .setPosition(20, 150)
          .setSize(220, 40)
          .setColorForeground(0xff00aa00) // ONの色
          .setColorBackground(0xff006600) // OFFの色
            ;
   cp5.getController("START")
      .getCaptionLabel()
        .setFont(font)
          .toUpperCase(false)
            .setSize(24)
            .setVisible(true) // ★デフォルトで表示
              ;
              
  //STOPボタン
   cp5.addButton("STOP")
        .setPosition(250, 150)
          .setSize(220, 40)
          .setColorForeground(0xffaa0000) // ONの色
          .setColorBackground(0xff660000) // OFFの色
            ;
   cp5.getController("STOP")
      .getCaptionLabel()
        .setFont(font)
          .toUpperCase(false)
            .setSize(24)
            .setVisible(true) // ★デフォルトで表示
              ;
              
   //MODE CHANGEボタン
   cp5.addButton("MODE_CHANGE")
        .setPosition(20, 200)
          .setSize(450, 40)
          .setCaptionLabel("Change to MANUAL Mode")
            ;
   cp5.getController("MODE_CHANGE")
      .getCaptionLabel()
        .setFont(font)
          .toUpperCase(false)
            .setSize(24)
              ;
}

/**
 * frameの描画の度に呼ばれる<br>
 *  <ul>
 *    <li>背景を塗りつぶし<li>
 *  </ul>
 *
 * @param void
 * @return void
 */
void draw()
{  
  //背景を塗りつぶし
  background(0);
  comp.updateUI();  
  
  // 走行中フラグ(is_running)がtrueの時だけ、時間経過でdutyを切り替える
  if (port != null && is_running && millis() - last_toggle_time > interval_time) 
  {
    last_toggle_time = millis(); // タイマーをリセット
    
    float current_duty_ratio;
    // dutyの状態をトグル（切り替え）
    if (is_duty_high) {
      current_duty_ratio = 0.3; // 30% duty
      is_duty_high = false;
    } else {
      current_duty_ratio = 1.0; // 100% duty
      is_duty_high = true;
    }
    
    // コマンド送信
    port.write(command0(current_duty_ratio)); // モーターduty設定
    port.write(command1(0)); // 右LEDは消灯
    port.write(command2(0)); // 左LEDは消灯
  }
  
  // 現在のモードと操作方法の表示
  fill(255);
  textSize(20);
  text("Mode: " + current_mode, 20, 270);
  
  if (current_mode.equals("MANUAL")) {
    textSize(16);
    text("Keys: [W] 100%  [S] 30%  [Space] Stop", 20, 290);
  }
}  



/**
 * ボタンが押されるたびに呼ばれる<br>
 *
 * @param void
 * @return void
 */
public void controlEvent(ControlEvent theEvent) {

  //CONNECTボタンを押したときの処理
  if (theEvent.getController().getName() == "CONNECT"  )
  {
    if (flag_CONNECT_button_created == true) {
      try {
        port = new Serial(this, com_port, 115200);  // select port
        println("接続に成功しました.");
        comp.changeBoxColor(color(200, 50, 50, 100));
      }
      catch (RuntimeException e) {
        println("COM portが開けません.");
        comp.changeBoxColor(color(0, 155, 255, 50));
      }
    }

    if (flag_CONNECT_button_created == false) flag_CONNECT_button_created = true;
  }
  //DISCONNECTボタンを押したときの処理
  if (theEvent.getController().getName() == "DISCONNECT" )
  {

    if (flag_DISCONNECT_button_created == true) {
      try {
        // 接続解除時に走行中なら停止コマンドを送る
        if(is_running){
          is_running = false;
          port.write(command0(0.0)); // モーター停止
          port.write(command1(0)); // LED消灯
          port.write(command2(0)); // LED消灯
        }

        port.stop();
        println("接続を解除しました.");
        comp.changeBoxColor(color(0, 155, 255, 50));
        port = null;
      }
      catch (NullPointerException e) {
        println("接続の解除に失敗しました.");
        comp.changeBoxColor(color(0, 155, 255, 50));
      }
    }

    if (flag_DISCONNECT_button_created == false) flag_DISCONNECT_button_created = true;
  }
  //STARTボタンを押したときの処理
  if (theEvent.getController().getName() == "START" )
  {
    // インターバルモード中のみ有効
    if (current_mode.equals("INTERVAL")) {
      if (port != null && !is_running) { // 接続中かつ停止中のみ
        println("走行開始 (インターバルモード)");
        is_running = true; 
        is_duty_high = false; 
        last_toggle_time = millis(); 
        
        port.write(command0(0.3)); 
        port.write(command1(0));
        port.write(command2(0));
      }
    }
  }
  
  //STOPボタンを押したときの処理
  if (theEvent.getController().getName() == "STOP" )
  {
    // インターバルモード中のみ有効
    if (current_mode.equals("INTERVAL")) {
      if (port != null && is_running) { // 接続中かつ走行中のみ
        println("走行停止 (インターバルモード)");
        is_running = false; 
        
        port.write(command0(0.0));
        port.write(command1(0));
        port.write(command2(0));
      }
    }
  }
  
  //MODE_CHANGEボタンを押したときの処理
  if (theEvent.getController().getName() == "MODE_CHANGE" )
  {
    // モーターを停止
    if (port != null) {
      port.write(command0(0.0));
    }
    
    // モードを切り替え
    if (current_mode.equals("INTERVAL")) {
      current_mode = "MANUAL";
      if (is_running) {
        is_running = false;
      }
      println("マニュアルモードへ変更");
      theEvent.getController().setCaptionLabel("Change to INTERVAL Mode");
      
      // START/STOPボタンを非表示
      cp5.getController("START").setVisible(false);
      cp5.getController("STOP").setVisible(false);
      
    } else { // MANUAL の場合
      current_mode = "INTERVAL";
      println("インターバルモードへ変更");
      theEvent.getController().setCaptionLabel("Change to MANUAL Mode");
      
      // START/STOPボタンを表示
      cp5.getController("START").setVisible(true);
      cp5.getController("STOP").setVisible(true);
    }
  }
  
}

//キーボードが押されたときに呼ばれる (マニュアルモード)
void keyPressed() {
  
  // 接続されていないか、マニュアルモードでない場合は何もしない
  if (port == null || !current_mode.equals("MANUAL")) {
    return;
  }
  
  // テキストフィールドがフォーカスされている場合はキー操作を無効にする
  if (comp.tf.isFocus()) {
    return;
  }

  // 'w'キー: Duty 100%
  if (key == 'w' || key == 'W') {
    println("マニュアル: 100%");
    port.write(command0(1.0));
  } 
  // 's'キー: Duty 30%
  else if (key == 's' || key == 'S') {
    println("マニュアル: 30%");
    port.write(command0(0.3));
  } 
  // スペースキー: 停止
  else if (key == ' ') {
    println("マニュアル: 停止");
    port.write(command0(0.0));
  }
}
