package kd.shared_lists;

import android.content.Context;
import android.net.ConnectivityManager;
import android.net.NetworkInfo;
import android.os.AsyncTask;
import android.support.v7.app.ActionBarActivity;
import android.os.Bundle;
import android.view.Menu;
import android.view.MenuItem;
import android.widget.TextView;

import java.io.BufferedWriter;
import java.io.OutputStreamWriter;
import java.io.PrintWriter;
import java.net.Inet4Address;
import java.net.InetAddress;
import java.net.Socket;


public class HomeScreen extends ActionBarActivity {
    private TextView tv;
    public static final int SERVERPORT = 5437;
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        testNet();
        new sendMessageTask().execute("foobar");
    }

    private void testNet() {
        setContentView(R.layout.layout_home_screen);
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
        // new lists need title, kyle sends me id
        try {
            InetAddress addr = InetAddress.getByName("104.236.186.39");
            //InetAddress addr = InetAddress.getByName("127.0.0.0");
            Socket socket = new Socket(addr, SERVERPORT);
            PrintWriter out = new PrintWriter(new BufferedWriter(new OutputStreamWriter(socket.getOutputStream())), true);
            if (out != null) {
                if (!out.checkError()) {
                    tv.setText("sending");
                    out.println("CHECK IT OUT");
                } else {
                    tv.setText("errror");
                }
            } else {
                tv.setText("null");
            }
            out.flush();
            socket.close();
            //tv.setText("Sent");
        } catch (java.net.UnknownHostException e) {
            tv.setText("unknown host");
        } catch (java.io.IOException e) {
            tv.setText("io exception");
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