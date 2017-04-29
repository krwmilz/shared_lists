package ca.absentmindedproductions.shlist;

import android.os.AsyncTask;
import android.util.Log;

import java.io.BufferedWriter;
import java.io.IOException;
import java.io.OutputStreamWriter;
import java.io.PrintWriter;
import java.net.Socket;

public class SendMessage extends AsyncTask<String, Void, String> {
    @Override
    protected String doInBackground(String... urls) {
        String result = "foo";
        Socket socket = null;
        try {
            socket = new Socket(urls[0], Integer.parseInt(urls[1]));
            PrintWriter out = new PrintWriter(new BufferedWriter(new OutputStreamWriter(socket.getOutputStream())), true);
            out.print(urls[2]);
            out.flush();
            socket.close();
        } catch (IOException e) {
            e.printStackTrace();
        }
        return result;
    }
}
