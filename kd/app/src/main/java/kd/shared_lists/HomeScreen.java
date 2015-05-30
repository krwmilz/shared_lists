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
import android.telephony.TelephonyManager;
import android.view.Menu;
import android.view.MenuItem;
import android.view.View;
import android.widget.Button;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.RelativeLayout;
import android.widget.TextView;

import org.w3c.dom.Text;

import java.io.BufferedReader;
import java.io.BufferedWriter;
import java.io.DataOutputStream;
import java.io.InputStreamReader;
import java.io.OutputStreamWriter;
import java.io.PrintWriter;
import java.net.Inet4Address;
import java.net.InetAddress;
import java.net.Socket;
import java.nio.ByteBuffer;


public class HomeScreen extends ActionBarActivity {
    private TextView tv;
    public String number;
    EditText numbertv;
    EditText nametv;
    String message = "juice";
    public String name;
    public static final int SERVERPORT = 5437;
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        TelephonyManager tMgr = (TelephonyManager) this.getSystemService(Context.TELEPHONY_SERVICE);
        String mPhoneNumber = tMgr.getLine1Number();
        setContentView(R.layout.layout_home_screen);
        final Button sendMsgButton = (Button) findViewById(R.id.sendMsgButton);
        numbertv = (EditText) findViewById(R.id.number);
        nametv = (EditText) findViewById(R.id.name);
        sendMsgButton.setText(mPhoneNumber);
        sendMsgButton.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                new sendMessageTask().execute("foobar", "joobar");
                sendMsgButton.setText(message);
            }
        });
    }



    private void testNet() {
        ConnectivityManager connMgr = (ConnectivityManager) getSystemService(Context.CONNECTIVITY_SERVICE);
        NetworkInfo networkInfo = connMgr.getActiveNetworkInfo();
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
                    //byte length = (byte) message.length();
                    byte length = 00000001;
                    byte[] mtype = {0x00, 0x01};
                    byte[] mtype2 = {0x00, 0x1f};
                    //byte[] bytes = ByteBuffer.allocate(2).putInt(45).array();
                    //out.println(type + length + message);
                    socket.getOutputStream().write(mtype);
                    socket.getOutputStream().write(mtype2);
                    out.print("1\0p");
      //              tv.setText();
                } else {
        //            tv.setText("errror");
                }
            } else {
          //      tv.setText("null");
            }
            BufferedReader in = new BufferedReader(new InputStreamReader(socket.getInputStream()));
            boolean listening = true;
            out.flush();

            while (listening) {
                message = in.readLine();
                break;
            }
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