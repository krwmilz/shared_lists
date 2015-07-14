package drsocto.shlist;

import android.content.Context;
import android.os.AsyncTask;
import android.util.Log;

import java.io.BufferedReader;
import java.io.BufferedWriter;
import java.io.IOException;
import java.io.InputStreamReader;
import java.io.OutputStreamWriter;
import java.io.PrintWriter;
import java.net.Socket;
import java.net.UnknownHostException;

/**
 * Created by David on 7/12/2015.
 */
public class NetMan {
    private String addr;
    private int port;
    Socket socket;
    Context context;

    public NetMan(String addr, int port, Context theContext) {
        this.addr = addr;
        this.port = port;
        context = theContext;
    }

    public int openSocket() {
        try {
            socket = new Socket(addr, port);
            return 0;
        } catch (UnknownHostException e) {
            Log.d("NetMan", "Unknown Host Excetion");
            return 1;
        } catch (IOException e) {
            Log.d("NetMan", "IO Exception");
            return 2;
        }
    }

    public int closeSocket() {
        try {
            socket.close();
            return 0;
        } catch (IOException e) {
            Log.d("NetMan", "IOException" + e);
            return 2;
        }
    }

    public String sendMessage(String[] message) {
        Log.d("NetMan", "In sendMessage");
        int mTypeInt = lookupMessageType(message[1]);
        byte[] type = toByteArray(mTypeInt);
        byte[] length = toByteArray(message[0].length());
        //Log.d("HomeScreen", "Resulting type array is of size: " + type.length);
        //Log.d("HomeScreen", "Resulting length array is of size: " + type.length);
        if (openSocket() == 0) {
            try {
                PrintWriter out = new PrintWriter(new BufferedWriter(new OutputStreamWriter(socket.getOutputStream())), true);
                socket.getOutputStream().write(type);
                Log.d("NetMan", "Sent Message Type: 3");
                socket.getOutputStream().write(length);
                Log.d("NetMan", "Sent Message Type: " + message[0].length());
                Log.d("NetMan", "Sending Message: " + message[0]);
                out.print(message[0]);
                out.flush();
                BufferedReader in = new BufferedReader(new InputStreamReader(socket.getInputStream()));
                String response = in.readLine();
                Log.d("NetMan", "Received Device ID: " + response);
                DBHelper dbh = new DBHelper("shlist.db", context);
                dbh.openOrCreateDB();
                dbh.setDeviceID(response, message[0]);
                if (mTypeInt == 1) {
                    String[] messageParts = message[0].split("\0");
                    response = messageParts[1] + " - " + response;
                }
                return response;

            } catch (IOException e) {
                Log.d("NetMan", "IOException" + e);
            }
            closeSocket();
        }
        return "Failed";
    }

    public int lookupMessageType(String mTypeStr) {
        if (mTypeStr.equals("new_list")) {
            return 1;
        } else if (mTypeStr.equals("new_device")) {
            return 3;
        }
        return -1;
    }

    public static byte[] toByteArray(long value)
    {
        byte[] ret = new byte[2];
        ret[1] = (byte) ((value >> ((0)*8) & 0xFF));
        ret[0] = (byte) ((value >> ((1)*8) & 0xFF));
        return ret;
    }
}
