package kd.shared_lists;

import android.animation.AnimatorSet;
import android.app.Dialog;
import android.content.Context;
import android.content.DialogInterface;
import android.net.ConnectivityManager;
import android.net.NetworkInfo;
import android.os.AsyncTask;
import android.support.v7.app.ActionBarActivity;
import android.os.Bundle;
import android.view.Menu;
import android.view.MenuItem;
import android.view.View;
import android.widget.Button;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.RelativeLayout;
import android.widget.TextView;

import org.w3c.dom.Text;

import java.io.BufferedWriter;
import java.io.OutputStreamWriter;
import java.io.PrintWriter;
import java.net.Inet4Address;
import java.net.InetAddress;
import java.net.Socket;


public class HomeScreen extends ActionBarActivity {
    private TextView tv;
    public String number;
    EditText numbertv;
    EditText nametv;
    public String name;
    public static final int SERVERPORT = 5437;
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.layout_home_screen);
        Button sendMsgButton = new Button(this);
        numbertv = new EditText(this);
        numbertv.setText("4039235990");
        nametv = new EditText(this);
        nametv.setText("puffdaddy");
        sendMsgButton.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                new sendMessageTask().execute("foobar", "joobar");
            }
        });
        LinearLayout rl = (LinearLayout) findViewById(R.id.mainlayout);
        sendMsgButton.setText("Send Message");
        rl.addView(sendMsgButton);
        rl.addView(numbertv);
        rl.addView(nametv);
    }

    private void testNet() {
        ConnectivityManager connMgr = (ConnectivityManager) getSystemService(Context.CONNECTIVITY_SERVICE);
        NetworkInfo networkInfo = connMgr.getActiveNetworkInfo();
        tv = (TextView) findViewById(R.id.hellotext);
        if (networkInfo != null && networkInfo.isConnected()) {
            tv.setText("Connected");
        } else {
            tv.setText("Disconnected");
        }
    }

    private class sendMessageTask extends AsyncTask<String, Void, String> {
        @Override
        protected String doInBackground(String... urls) {
            sendMessage();
            return "hey";
        }
    }

    public void sendMessage() {
//        setContentView(R.layout.layout_home_screen);
        // new lists need title, kyle sends me id
        try {
            InetAddress addr = InetAddress.getByName("104.236.186.39");
            //InetAddress addr = InetAddress.getByName("127.0.0.0");
            number = numbertv.getText().toString();
            name = nametv.getText().toString();
            //tv = (TextView) findViewById(R.id.hellotext);
            //tv.setText(number + "\0" + name);
            Socket socket = new Socket(addr, SERVERPORT);
            PrintWriter out = new PrintWriter(new BufferedWriter(new OutputStreamWriter(socket.getOutputStream())), true);
            if (out != null) {
                if (!out.checkError()) {
//                    tv.setText("sending");
                    String message = number + "\0" + name;
                    String type = "1";
                    int length = message.length();
                    out.println(type + length + message);
      //              tv.setText("Sent: " + type + length + message);
                } else {
        //            tv.setText("errror");
                }
            } else {
          //      tv.setText("null");
            }
            out.flush();
            socket.close();
            //tv.setText("Sent");
        } catch (java.net.UnknownHostException e) {
            //tv.setText("unknown host");
        } catch (java.io.IOException e) {
            //tv.setText("io exception");
        }
    }

    @Override
    public boolean onCreateOptionsMenu(Menu menu) {
        // Inflate the menu; this adds items to the action bar if it is present.
        getMenuInflater().inflate(R.menu.menu_home_screen, menu);
        return true;
    }

    @Override
    public boolean onOptionsItemSelected(MenuItem item) {
        // Handle action bar item clicks here. The action bar will
        // automatically handle clicks on the Home/Up button, so long
        // as you specify a parent activity in AndroidManifest.xml.
        int id = item.getItemId();

        //noinspection SimplifiableIfStatement
        if (id == R.id.action_settings) {
            return true;
        }

        return super.onOptionsItemSelected(item);
    }
}