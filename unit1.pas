unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, StdCtrls,
  ComCtrls, DBGrids, ExtCtrls, LazWebkitSettings, LazWebkitCtrls, mysql55conn,
  sqldb, db, types;

const PROGRAM_ID='0';

type
  { TForm1 }

  TForm1 = class(TForm)
    browser: TWebkitBrowser;
    Button1: TButton;
    Button2: TButton;
    btnStart: TButton;
    btnStop: TButton;
    Button3: TButton;
    Button4: TButton;
    Edit1: TEdit;
    Edit2: TEdit;
    Edit3: TEdit;
    Label1: TLabel;
    Label2: TLabel;
    MySQL55Connection1: TMySQL55Connection;
    PageControl1: TPageControl;
    checkQuery: TSQLQuery;
    checkQueryTransaction: TSQLTransaction;
    TimerForRestart: TTimer;
    UpdateQueryTransaction: TSQLTransaction;
    UpdateQuery: TSQLQuery;
    browserTab: TTabSheet;
    TabSheet2: TTabSheet;
    Timer1: TTimer;
    WebkitSettings1: TWebkitSettings;
    procedure browserLoaded(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure btnStartClick(Sender: TObject);
    procedure btnStopClick(Sender: TObject);
    procedure Button3Click(Sender: TObject);
    procedure Button4Click(Sender: TObject);
    procedure Edit1Enter(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormResize(Sender: TObject);
    procedure browserTabContextPopup(Sender: TObject; MousePos: TPoint;
      var Handled: Boolean);
    procedure Timer1Timer(Sender: TObject);
    //custom procedures and functions
    //initialize markers which will be used in events
    procedure InitMarkers(isFirstStart:Boolean);
    //insert into log some event without any details about task
    procedure insertEventToLog(eventMsg:String);
    //for details about some task insert into log some event
    procedure insertTaskEventToLog(eventMsg:String;taskID:String);
    procedure TimerForRestartTimer(Sender: TObject);
    //update status for some task in a tasks table
    procedure updateCurrentTaskStatus(newStatus:String;taskID:String);
    //update how much Money Need for bid now
    procedure updateMoneyNeedNow(moneyneed:String;taskID:String);
    //loaded page with new order for bid complete it with next function
    procedure workWithNewTasks();
    //check if no new tasks for bids now
    function checkIfNoNewTasks():Boolean;
    //function for login into yahoo japan after tryin to bid
    function loginYahooAfterBidOrBuyTrying(taskID:String):Boolean;

    //function for bid on Yahoo
    procedure bidOnYahoo(taskID:String);

    //function for buynow on Yahoo
    procedure buyNowOnYahoo(taskID:String);

    //get price from html code
    function getPriceFromHTML(src:String):Integer;
    //get value from table with tasks
    function getValueDB(fieldName:String):String;
    //if after last click notification -> get price from html code
    function getOneMorePriceFromHTML(src:String):Integer;
    //if error js notify with bid price on modal window
    function getPriceWhenJSErrorBID(src:String):Integer;

    //start timer and monitoring for new bids
    procedure startBidsManager(msg:String);

  private

  public
    //marker for know if it firsr start of the program
     firstStart: Boolean;
    //marker for know if it new task
     isWorkWithNewTask: Boolean;
     //indicator for know if captcha detected
     isCaptcha: Boolean;
     ///indicator STOP NOW for stop all automation activity
     isStopNow: Boolean;
     ///indicator about we work wit login
     isLogin: Boolean;
     ///indicator for know if last bid click when page loaded
     isBidLastClick: Boolean;
     ///last BUY NOW click when page loaded
     isBuyNowLastClick: Boolean;
     ///check results from page after last click for BID
     isAfterLastClickBIDCheck: Boolean;
     ///check results from page after last click for BUY NOW
     isAfterLastClickBUYNOWCheck: Boolean;

     CURRENT_TASK_ID:String
  end;

var
  Form1: TForm1;

implementation
{$R *.lfm}

{ TForm1 }


procedure TForm1.Button1Click(Sender: TObject);
begin
  browser.LoadURI(edit1.Text);
end;






/////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////
//////////WHEN PAGE LOADED //////////////////////////////////
//////////////////////////////////////////////////////////////
procedure TForm1.browserLoaded(Sender: TObject);
var submitScript:String;
    scriptTmp:String;
  taskID:String;
  currentBIDPrice:Integer;
  HTMLSource:String;
  beginPos:Integer;
begin
////////////////////////////////////////
  //////////////////////////////////////////
  ////////////////////////////////////////////
  ////////////////////////////////
  //MOST IMPORTANT PART WHEN PAGE LOADED
  //NEED TO CHECK IF THERE WARNING MESSAGE
  //AND INIT() -> REMOVE ALL "IS MARKS(like isAfterLastClickBIDCheck)"
  //AND RESTART TIMER
  if(
     (browser.SearchText('入札する金額は、現在の入札額よりも高い値を設定してくださ',false,true,false))
     OR
     (browser.SearchText('この出品者のオークションへの入札はできません',false,true,false))
    )
    then begin
     taskID:=getValueDB('id');
     updateCurrentTaskStatus('Data error on Yahoo BID - Cancel',taskID);
     insertEventToLog('Data error on Yahoo BID - Cancel');
     //stop timer
     Timer1.Enabled:=false;
     isAfterLastClickBIDCheck:=false;
     isAfterLastClickBUYNOWCheck:=false;
     isBidLastClick:=false;
     isBuyNowLastClick:=false;
     InitMarkers(false);
     //start timer
     Timer1.Interval:=5000;
     Timer1.Enabled:=true;
     isStopNow:=false;
  end else begin
////////////////////////////////////////
  //////////////////////////////////////////
  ////////////////////////////////////////////
  ////////////////////////////////
              ///IF BuyNOW FINISH CLICK////////////////////////////////////////////////////////
            /////////////////LAST CLICK FOR BUYNOW CONTINUE HERE/////////////////////////////
            if(isBuyNowLastClick=true) then begin
              insertEventToLog('FINISH CLICK FOR BUY NOW!');
              scriptTmp:='x=document.getElementsByClassName("decBtm02")[0];';
              scriptTmp:=scriptTmp+'x.getElementsByTagName("input")[0].click();';
              browser.ExecuteScript(scriptTmp);
              scriptTmp:='';
              isAfterLastClickBUYNOWCheck:=true;
              isBuyNowLastClick:=false;
            end;
            //////-----BUY NOW----- AFTER FINISH CLICK CHECK RESULTS///////////
            if(isAfterLastClickBUYNOWCheck=true) then begin
              isAfterLastClickBUYNOWCheck:=false;
              taskID:=getValueDB('id');
              ////--------------
                 updateCurrentTaskStatus('WINNER',taskID);
                 insertTaskEventToLog('COMPLETE FINISH CLICK BUY NOW, STARTED TIMER!',taskID);
              InitMarkers(false);
              ////--------------
              if(isStopNow=false)then begin
              //update timer interval and enable timer
              Timer1.Interval:=5000;
              Timer1.Enabled:=true;
              end;
            end;
            //////-----BID----- AFTER FINISH CLICK CHECK RESULTS///////////
            if(isAfterLastClickBIDCheck=true) then begin
                      isAfterLastClickBIDCheck:=false;
                      taskID:=getValueDB('id');
                      ////--------------
                      ///try to find current bid price
                      HTMLSource:=browser.ExtractContent(TWebKitViewContentFormat.wvcfSourceText);
                      currentBIDPrice:=getOneMorePriceFromHTML(HTMLSource);
                      ////check one more time for not enough money
                      beginPos:=0;
                      beginPos:=AnsiPos('decErrorPoint',HTMLSource);
                      if(beginPos<>0)then begin
                      //String not found
                       updateCurrentTaskStatus('NOT ENOUGH MONEY',taskID);
                       updateMoneyNeedNow(IntToStr(currentBIDPrice),taskID);
                      end
                      else begin
                         updateCurrentTaskStatus('completed',taskID);
                         insertTaskEventToLog('COMPLETE FINISH CLICK BID, STARTED TIMER!',taskID);
                      end;

                      InitMarkers(false);
                      ////--------------
                      if(isStopNow=false)then begin
                      //update timer interval and enable timer
                      Timer1.Interval:=5000;
                      Timer1.Enabled:=true;
                      end;
            end;
            ///IF BID FINISH CLICK////////////////////////////////////////////////////////
            /////////////////LAST CLICK ON BUTTON FOR BID CONTINUE HERE/////////////////////////////
            if(isBidLastClick=true) then begin
              insertEventToLog('FINISH CLICK FOR MAKE BID!');
              scriptTmp:='x=document.getElementById("modFormSbt");';
              scriptTmp:=scriptTmp+'y=x.getElementsByTagName("input");';
              scriptTmp:=scriptTmp+'y[0].click();';
              browser.ExecuteScript(scriptTmp);
              scriptTmp:='';
              isAfterLastClickBIDCheck:=true;
              isBidLastClick:=false;
            end;
            ///////////IF LOGIN DO THIS SUBMIT
            if(isLogin=true)then begin
                 Timer1.Enabled:=false;
                 /////////////////CONTINUE HERE TO LOG IN/////////////////////////////
                   if(browser.SearchText('ログインしたままにする',false,true,false))then begin
                     insertEventToLog('FOUND Login Form Trying to Login!');
                     submitScript:='document.getElementById("username").value="Login_name_of_your_Yahoo_JAPAN";';
                     submitScript:=submitScript+'document.getElementById("passwd").value="PASSWORD_of_your_Yahoo_JAPAN";';
                     submitScript:=submitScript+'document.getElementById(".save").click();';
                     browser.ExecuteScript(
                      submitScript
                     );
                     submitScript:='';
                   end
                   ///now check if logging success!
                   else if(
                           (browser.SearchText('Login_name_of_your_Yahoo_JAPAN',false,true,false))
                           OR
                           (browser.SearchText('Login_name_of_your_Yahoo_JAPAN',false,true,false))
                           )then begin
                               insertEventToLog('SUCCESS LOGGED IN DETECTED!');
                               isLogin:=false;

                               //check if 'auction' or 'buynow'
                               if(getValueDB('AuctionOrBuyNow')='Auction' )then bidOnYahoo(getValueDB('id'));
                               if(getValueDB('AuctionOrBuyNow')='BuyNow')then buyNowOnYahoo(getValueDB('id'));

                   end
                   else begin
                      insertEventToLog('ERROR, WHEN TRIED TO LOGIN, NEED TO CHECK !');
                      //stop all works
                      InitMarkers(false);
                   end;
              end
              //////////
              //////IF MAKE BID FOR NEW TASK THEN THIS "workWIthTask"
              else if(isWorkWithNewTask=true)then begin
                 workWithNewTasks();
              end;
  end;
end;
 /////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////
//////////END OF PAGE LOADED //////////////////////////////////
//////////////////////////////////////////////////////////////








procedure TForm1.Button2Click(Sender: TObject);
var fileContent:TStringList;
  i:Integer;
begin
     //if(checkIfNoNewTasks()=true) then ShowMessage('NO Items');
     //if(checkIfNoNewTasks()=false) then ShowMessage('Yes Items');
     //bidOnYahoo();
     //fileContent:=TStringList.Create();
     //fileContent.LoadFromFile('srchtmlyahoojapan.html');
     //fileContent.LoadFromFile('TESTgetOneMorePriceFromHTML.html');
     //fileContent.LoadFromFile('wrong_price_bid_in_the_same_window.html');
     //if(AnsiPos('Login_name_of_your_Yahoo_JAPAN',fileContent.Text)<>0)then ShowMessage(IntToStr(AnsiPos('Login_name_of_your_Yahoo_JAPAN',fileContent.Text)));
     //ShowMessage(IntToStr(getPriceFromHTML(fileContent.Text)));
     //ShowMessage(IntToStr(getOneMorePriceFromHTML(fileContent.Text)));
     //ShowMessage(IntToStr(getPriceWhenJSErrorBID(fileContent.Text)));
     ////if(getOneMorePriceFromHTML(fileContent.Text)<>-1)then
     //ShowMessage('need more money for bid found');
     //ShowMessage(IntToStr(getPriceFromHTML('123456789<input type="text" name="Bid" value="9678" size="11" id="bid1" maxlength="13" onchange="toHankaku(this)" data-rapid_p="75">')));
end;

//button start
procedure TForm1.btnStartClick(Sender: TObject);
begin
startBidsManager('TASK MANAGER WAS EXECUTED BY HAND!');
end;

//button stop
procedure TForm1.btnStopClick(Sender: TObject);
begin
  ///inserts new event into log of tasks
  insertEventToLog('TASK MANAGER WAS STOPPED BY HAND!');
  Timer1.Enabled:=false;
  isStopNow:=true;

  //disable works with tasks when page loaded
  InitMarkers(false);
  btnStart.Enabled:=true;
end;

procedure TForm1.Button3Click(Sender: TObject);
var
    fileContent:TStringList;
begin
     fileContent:=TStringList.Create();
     fileContent.AddText(browser.ExtractContent(TWebKitViewContentFormat.wvcfSourceText));
     fileContent.SaveToFile(Edit3.Text);
     ShowMessage('Page saved to -> '+Edit3.Text);
end;

procedure TForm1.Button4Click(Sender: TObject);
var NeedRestart:String;
begin
    //check if need to restart a BIDS processes
    checkQuery.SQL.Text:='SELECT * FROM `programs_for_bids` WHERE id='+PROGRAM_ID;
    checkQuery.Open;
    NeedRestart:=checkQuery.Fields[2].AsString;
    checkQuery.Close;

    if(NeedRestart='1')then
      begin
        ShowMessage('1');
        UpdateQuery.SQL.Text:='UPDATE `programs_for_bids` SET NeedRestart=0  WHERE id='+PROGRAM_ID;
        UpdateQuery.ExecSQL;
        UpdateQueryTransaction.Commit;
      end
    else ShowMessage('0 -NeedRestart='+NeedRestart+' sql='+checkQuery.SQL.Text);
end;

procedure TForm1.Edit1Enter(Sender: TObject);
begin

end;

procedure TForm1.FormCreate(Sender: TObject);
begin
     InitMarkers(true);
     MySQL55Connection1.Connected:=true;
     startBidsManager('TASK MANAGER WAS EXECUTED ON PROGRAM START!');
end;

procedure TForm1.FormResize(Sender: TObject);
begin
  browser.Height:=Form1.Height-87;
  browser.Width:=Form1.Width-34;
  PageControl1.Height:=Form1.Height;
  PageControl1.Width:=Form1.Width-20;
end;

procedure TForm1.browserTabContextPopup(Sender: TObject; MousePos: TPoint;
  var Handled: Boolean);
begin

end;

procedure TForm1.Timer1Timer(Sender: TObject);
begin
  //check if first start of the program and insert a record into a DB about first start
  if(firstStart=true) then begin
    //update record in a DB with new satus "in Work"
    insertEventToLog('first start of execution of the program');
    firstStart:=false;
  end;

  //insertEventToLog('Timer -> '+IntToStr(Timer1.Interval)+' milliseconds');
  //Label1.Caption:='program_id=0; name_of_program="first test program for bid"';

    if(checkIfNoNewTasks()=true) then begin
      //insertEventToLog('NO NEW TASKS, WAIT -> '+IntToStr(Timer1.Interval)+' for new tasks check');
    end
    else begin
      ///Work with NEW Tasks
      //get url for bidding
      //go to by url address
      isWorkWithNewTask:=true;
      Edit1.Text:=getValueDB('Url');
      browser.LoadURI(Edit1.Text);
      browserTab.Show;
      //disable timer while work with browser
      Timer1.Enabled:=false;
    end;
end;

procedure TForm1.insertEventToLog(eventMsg:String);
begin
  UpdateQuery.SQL.Text:='INSERT INTO `log_of_program_for_bid`(status,`id_of_program_for_bid`) '+
  'VALUES("'+eventMsg+'",'+PROGRAM_ID+')';
  UpdateQuery.ExecSQL;
  UpdateQueryTransaction.Commit;
  Edit2.Text:=eventMsg;
end;

procedure TForm1.insertTaskEventToLog(eventMsg:String;taskID:String);
begin
  if(taskID<>'')then begin
    UpdateQuery.SQL.Text:='INSERT INTO `log_of_program_for_bid`(status,`current_task_id`,`id_of_program_for_bid`) '+
    'VALUES("'+eventMsg+'",'+taskID+','+PROGRAM_ID+')';
    UpdateQuery.ExecSQL;
    UpdateQueryTransaction.Commit;
    Edit2.Text:=eventMsg;
  end;
end;

procedure TForm1.TimerForRestartTimer(Sender: TObject);
var NeedRestart:String;
begin

  //check if need to restart a BIDS processes
    checkQuery.SQL.Text:='SELECT NeedRestart FROM `programs_for_bids` WHERE id='+PROGRAM_ID;
    checkQuery.Open;
    NeedRestart:=checkQuery.Fields[0].AsString;
    checkQuery.Close;

    if(NeedRestart='1')then
      begin
        UpdateQuery.SQL.Text:='UPDATE `programs_for_bids` SET NeedRestart=0  WHERE id='+PROGRAM_ID;
        UpdateQuery.ExecSQL;
        UpdateQueryTransaction.Commit;
        //STOP
        ///inserts new event into log of tasks
        insertEventToLog('TASK MANAGER WAS STOPPED IN AUTOMATION MODE DUE EXCEPTON!');
        Timer1.Enabled:=false;
        isStopNow:=true;

        //disable works with tasks when page loaded
        InitMarkers(false);
        btnStart.Enabled:=true;
        //START
        startBidsManager('TASK MANAGER WAS EXECUTED IN AUTOMATION MODE DUE EXCEPTON!!');
      end;
end;

procedure TForm1.updateCurrentTaskStatus(newStatus:String;taskID:String);
begin
  if((newStatus<>'')AND(taskID<>''))then begin
    UpdateQuery.SQL.Text:='Update `tasks_for_bid` SET status="'+newStatus+'",`time_of_last_event`=NOW() WHERE id='+taskID;
    UpdateQuery.ExecSQL;
    UpdateQueryTransaction.Commit;
  end;
end;

procedure TForm1.updateMoneyNeedNow(moneyneed:String;taskID:String);
begin
  if((moneyneed<>'')AND(taskID<>''))then begin
    UpdateQuery.SQL.Text:='Update `tasks_for_bid` SET MoneyNeedNow="'+moneyneed+'",`time_of_last_event`=NOW() WHERE id='+taskID;
    UpdateQuery.ExecSQL;
    UpdateQueryTransaction.Commit;
  end;
end;

procedure TForm1.workWithNewTasks();
var taskID:String;
begin

  taskID:=getValueDB('id');
  ///inerts new event into log of tasks
  insertTaskEventToLog('NEW BID : browse by url -> '+Edit1.Text,taskID);

  ///////////////////////////////////////////////////////////////
  ///////////////////////////////////////////////////////////////
  ///////TODO : here must be functions for make bid
  ///////////////////or buynow for new items//
  ///////////////////////////////////////////////////////////////
  ///////////////////////////////////////////////////////////////

  //check if 'auction' or 'buynow'
  if(getValueDB('AuctionOrBuyNow')='Auction' )then bidOnYahoo(getValueDB('id'));
  if(getValueDB('AuctionOrBuyNow')='BuyNow')then buyNowOnYahoo(getValueDB('id'));
end;

function TForm1.checkIfNoNewTasks():Boolean;/////here update CURRENT_TASK_ID if has new tasks
var isNoNewTasks:Boolean;
  CountOfFields:String;
begin
   //by default we have new tasks
   isNoNewTasks:=false;

  ///first get count of fields
  checkQuery.SQL.Text:='SELECT Count(*) FROM `tasks_for_bid` WHERE `id_of_program_for_bid`='+PROGRAM_ID+' AND status="pending"';
  checkQuery.Open;
  CountOfFields:=checkQuery.Fields[0].AsString;
  checkQuery.Close;

  if StrToInt(CountOfFields)=0 then begin
   isNoNewTasks:=true;
   CURRENT_TASK_ID:='-1';
  end
  else begin///if new tasks exists
    checkQuery.SQL.Text:='SELECT * FROM `tasks_for_bid` WHERE `id_of_program_for_bid`='+PROGRAM_ID+' AND status="pending" ORDER BY id DESC';
    checkQuery.Open;
    CURRENT_TASK_ID:=checkQuery.Fields[0].AsString;
    checkQuery.Close;
  end;
  result:=isNoNewTasks;
end;

function TForm1.loginYahooAfterBidOrBuyTrying(taskID:String):Boolean;
begin

  isCaptcha:=false;
  isLogin:=true;

  //click button and continue in page loaded
  insertTaskEventToLog('PASS to LOGIN NOW!',taskID);
     browser.ExecuteScript(
      'document.getElementsByClassName("Button Button--dark")[0].click();'
     );
end;

procedure TForm1.bidOnYahoo(taskID:String);
var
  OurMoneyForBID:Integer;
  HTMLSource:String;
  currentBIDPrice:Integer;
begin

     //load source of the HTML page
     HTMLSource:=browser.ExtractContent(TWebKitViewContentFormat.wvcfSourceText);


   /////////////////////////////////////////////////
   ///////////0. -->>  OPTION CAN --> YOUR BID IS MAX/////////
   /////////////////////////////////////////////////
   /////check if YOUR BID IS MAX
   if(browser.SearchText('あなたが現在の最高額入札者です',false,true,false))then begin
      //update item status
      //update record in a DB with new satus "END"
      updateCurrentTaskStatus('YOUR BID MAX',taskID);
      ///inerts new event into log of tasks
      insertTaskEventToLog('AUCTION WAS ENDED',taskID);
      if(isStopNow=false)then begin
       //update timer interval and enable timer
       Timer1.Interval:=5000;
       Timer1.Enabled:=true;
      end;
     end
  else
  /////////////////////////////////////////////////
  ///////////1. -->>  OPTION CAN --> ENDED/////////
  /////////////////////////////////////////////////
  /////check if auction was ENDED
  if(browser.SearchText('残り時間	： 	終了',false,true,false))then begin
   //update item status
   //update record in a DB with new satus "END"
   updateCurrentTaskStatus('END',taskID);
   ///inerts new event into log of tasks
   insertTaskEventToLog('AUCTION WAS ENDED',taskID);
   if(isStopNow=false)then begin
    //update timer interval and enable timer
    Timer1.Interval:=5000;
    Timer1.Enabled:=true;
   end;
  end
  else begin
     /////////////////////////////////////////////////
    ///////////01. -->>  OPTION CAN --> BUY IT NOW BUTTON/////////
    /////////////////////////////////////////////////
     /////check if there only button for BUY IT NOW
     if(
        (AnsiPos('rsec:byitnw;pos:1',HTMLSource)<>0)//found buy it now
        AND
        (AnsiPos('rsec:bds;pos:1',HTMLSource)=0)// and no found bid button
       )then begin
         //update item status
         //update record in a DB with new satus "END"
         updateCurrentTaskStatus('NO BID, BUY IT NOW',taskID);
         ///inerts new event into log of tasks
         insertTaskEventToLog('NO BID, BUY IT NOW',taskID);

         buyNowOnYahoo(taskID);

     end
     else begin

      ///write event about trying to bid
      insertTaskEventToLog('Trying to BID on yahoo auction!',taskID);

      browser.ExecuteScript(
       'var x=document.getElementById("box1").click();'
      );

  /////////////////////////////////////////////////////////
  ///////////2. -->>  OPTION CAN --> NO LOGIN DETECTED/////
  /////////////////////////////////////////////////////////
  //if found window with login notification
  if(browser.SearchText('ログイン',false,true,false))then begin
   insertTaskEventToLog('You are not logged In, GO TO Login Function!',taskID);
   ///////////////////////////////
   ////need to login//////////////
   ///////////////////////////////
     loginYahooAfterBidOrBuyTrying(taskID);
     //ONLY for test
      //ShowMessage('You are not logged In, GO TO Login Function!');
      //Timer1.Enabled:=false;
      //exit;
      //END OF ONLY for test
     //
  end
  else begin
     //////////////////////////////////////////////////////////
     ///////////3. -->>  OPTION CAN --> TRY TO BID/////////////
     //////////////////////////////////////////////////////////
     if(AnsiPos('Login_name_of_your_Yahoo_JAPAN',HTMLSource)<>0)//FOUND LOGIN
     //browser.SearchText('Login_name_of_your_Yahoo_JAPAN',false,true,false))
     then begin

       insertTaskEventToLog('Already LOGGED IN DETECTED!',taskID);

       OurMoneyForBID:=StrToInt(getValueDB('MoneyToBid'));

       ///////////////////////////////////////
       ///try to find current bid price     /
       ///////////////////////////////////////
       currentBIDPrice:=getPriceFromHTML(HTMLSource);
       Label1.Caption:='currentBIDPrice='+IntToStr(currentBIDPrice)+'; OurMoneyForBID='+IntToStr(OurMoneyForBID);
       ///IF NO FOUND price
       if(currentBIDPrice=-1)then begin
         //update item status
         //update record in a DB
         updateCurrentTaskStatus('ERROR getPriceFromHTML -1',taskID);
         ///inerts new event into log of tasks
         insertTaskEventToLog('no found price on an html page',taskID);
         //continue to work
         if(isStopNow=false)then begin
           //update timer interval and enable timer
           Timer1.Interval:=5000;
           Timer1.Enabled:=true;
          end;
       end
       ///NOW CHECK IF Enough money for make a bid
       else if(currentBIDPrice<=OurMoneyForBID)then begin


        ///OPEN WINDOW WITH BID value
         browser.ExecuteScript(
          'document.getElementsByClassName("Button Button--bid js-modal-show rapidnofollow")[0].click();');
         ///NOW SETUP OUR VALUE FOR BID BEFORE CLICK
         browser.ExecuteScript(
         'document.getElementsByClassName("BidModal__inputPrice js-validator-price")[0].value='+IntToStr(OurMoneyForBID)+';'
         );
         //click on button for make a bid
         browser.ExecuteScript(
          'document.getElementsByClassName("js-validator-submit")[0].click();'
         );

           //one more check if js error for bid price
           if(browser.SearchText('以上の金額で入札できます',false,true,false))then begin
                     //if found this price error
                     //load one more time html page with last updates
                     HTMLSource:=browser.ExtractContent(TWebKitViewContentFormat.wvcfSourceText);
                     currentBIDPrice:=getPriceWhenJSErrorBID(HTMLSource);
                     ///IF NO FOUND JS ERROR notify BID price
                       if(currentBIDPrice=-1)then begin
                         //update item status
                         //update record in a DB
                         updateCurrentTaskStatus('ERROR getPriceWhenJSErrorBID -1',taskID);
                         ///inerts new event into log of tasks
                         insertTaskEventToLog('no found js error notify price on an html page',taskID);
                         isStopNow:=true;//stop here, bad error
                       end
                       else begin
                         updateCurrentTaskStatus('NOT ENOUGH MONEY',taskID);
                         updateMoneyNeedNow(IntToStr(currentBIDPrice),taskID);
                         ///inerts new event into log of tasks
                         insertTaskEventToLog('NOT ENOUGH MONEY',taskID);
                          if(isStopNow=false)then begin
                            //update timer interval and enable timer
                            Timer1.Interval:=5000;
                            Timer1.Enabled:=true;
                           end;
                       end;
           end;

         ///inerts new event into log of tasks
         insertTaskEventToLog('1-st BID BUTTON CLICKED, GO TO NEXT MAKE BID PAGE!',taskID);
         isBidLastClick:=true;///for continue with it in page loaded event
        end
       ////////////////////////////////////////////////////////////////
       ///////////4. -->>  OPTION CAN --> NOT ENOUGH MONEY/////////////
       ////////////////////////////////////////////////////////////////
        else if(currentBIDPrice>OurMoneyForBID) then begin////if not enough money for make a bid
         //update item status
         //update record in a DB
         updateCurrentTaskStatus('NOT ENOUGH MONEY',taskID);
         updateMoneyNeedNow(IntToStr(currentBIDPrice),taskID);
         ///inerts new event into log of tasks
         insertTaskEventToLog('NOT ENOUGH MONEY',taskID);
          if(isStopNow=false)then begin
            //update timer interval and enable timer
            Timer1.Interval:=5000;
            Timer1.Enabled:=true;
           end;
        end;
        InitMarkers(false);
     end;
     end;
   end;
  end;
end;




//-----------------------------------------------------------------------//
//-----------------------------------------------------------------------//
//----------BUY NOW ON YAHOO JAPAN---------------------------------------//
//-----------------------------------------------------------------------//
//-----------------------------------------------------------------------//
procedure TForm1.buyNowOnYahoo(taskID:String);
var
  OurMoneyForBID:Integer;
  HTMLSource:String;
  currentBIDPrice:Integer;
begin

  //load source of the HTML page
  HTMLSource:=browser.ExtractContent(TWebKitViewContentFormat.wvcfSourceText);

 /////////////////////////////////////////////////
    ///////////01. -->>  OPTION CAN -->///////////
    //!!!--NOT FOUND--!!! BUY IT NOW BUTTON/////////
    /////////////////////////////////////////////////
      ///write event about trying to buy now
      insertTaskEventToLog('Trying to BuyNow on yahoo auction!',taskID);

     /////check if there only button for BUY IT NOW
     if(AnsiPos('rsec:byitnw;pos:1',HTMLSource)=0)//!!! NOT found buy it now
        then begin
         //update item status
         //update record in a DB with new satus "END"
         updateCurrentTaskStatus('BUY IT NOW - NOT FOUND',taskID);
         ///inerts new event into log of tasks
         insertTaskEventToLog('BUY IT NOW - NOT FOUND, Stop',taskID);
         if(isStopNow=false)then begin
          //update timer interval and enable timer
          Timer1.Interval:=5000;
          Timer1.Enabled:=true;
         end;
     end
  else
  /////////////////////////////////////////////////
  ///////////1. -->>  OPTION CAN --> ENDED/////////
  /////////////////////////////////////////////////
  /////check if auction was ENDED
  if(browser.SearchText('残り時間	： 	終了',false,true,false))then begin
   //update item status
   //update record in a DB with new satus "END"
   updateCurrentTaskStatus('END',taskID);
   ///inerts new event into log of tasks
   insertTaskEventToLog('AUCTION WAS ENDED',taskID);
   if(isStopNow=false)then begin
    //update timer interval and enable timer
    Timer1.Interval:=5000;
    Timer1.Enabled:=true;
   end;
  end
  else begin

  /////////////////////////////////////////////////////////
  ///////////2. -->>  OPTION CAN --> NO LOGIN DETECTED/////
  /////////////////////////////////////////////////////////
  //if found window with login notification
  if(browser.SearchText('ログイン',false,true,false))then begin
   insertTaskEventToLog('You are not logged In, GO TO Login Function!',taskID);
   ///////////////////////////////
   ////need to login//////////////
   ///////////////////////////////
     loginYahooAfterBidOrBuyTrying(taskID);
     //ONLY for test
      //ShowMessage('You are not logged In, GO TO Login Function!');
      //Timer1.Enabled:=false;
      //exit;
      //END OF ONLY for test
     //
  end
  else begin
       //////////////////////////////////////////////////////////
       ///////////3. -->>  OPTION CAN --> TRY TO BUY NOW/////////////
       //////////////////////////////////////////////////////////
       if(AnsiPos('Login_name_of_your_Yahoo_JAPAN',HTMLSource)<>0)//FOUND LOGIN
       //browser.SearchText('Login_name_of_your_Yahoo_JAPAN',false,true,false))
       then begin

         insertTaskEventToLog('Already LOGGED IN DETECTED!',taskID);

         OurMoneyForBID:=StrToInt(getValueDB('MoneyToBid'));

       end;

       isBuyNowLastClick:=true;
       //press big button -> BuyNow
       browser.ExecuteScript('document.getElementsByClassName("Button Button--buynow js-modal-show rapidnofollow")[0].click();');
       //press modal window button -> BuyNow
       browser.ExecuteScript('document.getElementsByClassName("js-validator-submit")[0].click();');
     end;
  end;
end;




function TForm1.getPriceFromHTML(src:String):Integer;
var beginPos,
    endPos:Integer;
    price:Integer;
    newStr:String;
Begin
///code from page like below
//"items": {
//"guid": "CZ5A6YGWDBL5HYDSKKNESNEVGU",
//"productID": "u79933769",
//"productName": "★☆キャノン CANON EOS Kiss X7 ダブルズームキット 新品☆★",
//"productCategoryID": "2084261635",
//"price": "1",
//"winPrice": "52000",
//"quantity": "1",
//"bids": "0",
///here we just copy from "price": "1", -> it is auction current price

     beginPos:=AnsiPos('"price": "',src);
     newStr:=Copy(src,beginPos+10,Length(src));
     if(beginPos=0)then begin
       //String not found
       price:=-1;
     end
     else begin
       endPos:=AnsiPos('",',newStr);
       if(endPos=0)then
         price:=-1
        else begin
         try
 //         ShowMessage(Copy(newStr,1,endPos-1)); exit;
            price:=StrToInt(Copy(newStr,1,endPos-1));
         except
           price:=-1;
         end;
        end;
      end;
     result:=price;
end;

procedure TForm1.InitMarkers(isFirstStart:Boolean);
begin
     firstStart:=isFirstStart;
     isWorkWithNewTask:=false;
     isCaptcha:=false;
     isLogin:=false;
end;

function TForm1.getValueDB(fieldName:String):String;
var returnValue:String;
begin
     returnValue:='';
     checkQuery.SQL.Text:='SELECT * FROM `tasks_for_bid` WHERE `id_of_program_for_bid`='+PROGRAM_ID+' AND status="pending" AND id='+CURRENT_TASK_ID;
     checkQuery.Open;
     if(fieldName='id')then returnValue:=checkQuery.Fields[0].AsString;
     if(fieldName='userID')then returnValue:=checkQuery.Fields[1].AsString;
     if(fieldName='userName')then returnValue:=checkQuery.Fields[2].AsString;
     if(fieldName='Url')then returnValue:=checkQuery.Fields[3].AsString;
     if(fieldName='status')then returnValue:=checkQuery.Fields[4].AsString;
     if(fieldName='time_of_last_event')then returnValue:=checkQuery.Fields[5].AsString;
     if(fieldName='id_of_program_for_bid')then returnValue:=checkQuery.Fields[6].AsString;
     if(fieldName='MoneyToBid')then returnValue:=checkQuery.Fields[7].AsString;
     if(fieldName='AuctionOrBuyNow')then returnValue:=checkQuery.Fields[13].AsString;
     checkQuery.Close;
     result:=returnValue;
end;

function TForm1.getOneMorePriceFromHTML(src:String):Integer;
var beginPos,
    endPos:Integer;
    price:Integer;
Begin
     beginPos:=AnsiPos('name="Bid"',src);
     //showMessage(IntToStr(beginPos));
     if(beginPos=0)then begin
       //String not found
       price:=-1;
     end
     else begin
       endPos:=AnsiPos('" size="8">',src);

       if(endPos=0)then
         price:=-1
        else begin
         try
          price:=StrToInt(Copy(src,beginPos+18,endPos-(beginPos+18)));
         except
           price:=-1;
         end;
        end;

       //showMessage(IntToStr(endPos));
       //ShowMessage(Copy(src,beginPos+18,endPos-(beginPos+18)));
      end;
     result:=price;
end;

function TForm1.getPriceWhenJSErrorBID(src:String):Integer;
var beginPos,
    endPos:Integer;
    price:Integer;
Begin
     beginPos:=AnsiPos('<input type="hidden" name="setPrice" value="',src);
     //showMessage(IntToStr(beginPos));
     if(beginPos=0)then begin
       //String not found
       price:=-1;
     end
     else begin
       endPos:=AnsiPos('" class="js-validator-priceDefault"',src);

       if(endPos=0)then
         price:=-1
        else begin
         try
          price:=StrToInt(Copy(src,beginPos+44,endPos-(beginPos+44)));
         except
           price:=-1;
         end;
        end;

       //showMessage(IntToStr(endPos));
       //ShowMessage(Copy(src,beginPos+18,endPos-(beginPos+18)));
      end;
     result:=price;
end;

procedure TForm1.startBidsManager(msg:String);
Begin
///inerts new event into log of tasks
  insertEventToLog(msg);
  //update timer interval and enable timer
  Timer1.Interval:=5000;
  Timer1.Enabled:=true;
  isStopNow:=false;
  isLogin:=false;
  btnStart.Enabled:=false;
end;

end.

