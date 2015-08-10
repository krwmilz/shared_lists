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
    private final int NEW_DEVICE_MESSAGE_TYPE= 0;
    private final int NEW_LIST_MESSAGE_TYPE= 1;
    private final int LIST_REQUEST_MESSAGE_TYPE=3;
    private final int JOIN_LIST_MESSAGE_TYPE=4;
    private final int LEAVE_LIST_MESSAGE_TYPE=5;
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
        Log.d("NetMan", "Type is: " + mTypeInt);
        Log.d("NetMan", "message is: " + message[0]);
        byte[] length = toByteArray(message[0].length());
        //Log.d("HomeScreen", "Resulting type array is of size: " + type.length);
        //Log.d("HomeScreen", "Resulting length array is of size: " + type.length);
        if (openSocket() == 0) {
            try {
                PrintWriter out = new PrintWriter(new BufferedWriter(new OutputStreamWriter(socket.getOutputStream())), true);
                socket.getOutputStream().write(type);
                socket.getOutputStream().write(length);
                out.print(message[0]);
                out.flush();
                BufferedReader in = new BufferedReader(new InputStreamReader(socket.getInputStream()));
                String response = in.readLine();
                if (mTypeInt == NEW_DEVICE_MESSAGE_TYPE) {
                    Log.d("NetMan", "Received Device ID: " + response.substring(4));
                    DBHelper dbh = new DBHelper("shlist.db", context);
                    dbh.openOrCreateDB();
                    dbh.setDeviceID(response.substring(4), message[0]);
                    dbh.closeDB();
                } else if (mTypeInt == NEW_LIST_MESSAGE_TYPE) {
                    String[] messageParts = message[0].split("\0");
                    response = messageParts[1] + ":" + response.substring(4);
                } else if (mTypeInt == LIST_REQUEST_MESSAGE_TYPE) {
                    Log.d("NetMan", response.substring(4));
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
            return NEW_LIST_MESSAGE_TYPE;
        } else if (mTypeStr.equals("new_device")) {
            return NEW_DEVICE_MESSAGE_TYPE;
        } else if (mTypeStr.equals("get_lists")) {
            return LIST_REQUEST_MESSAGE_TYPE;
        } else if (mTypeStr.equals("join_list")) {
            return JOIN_LIST_MESSAGE_TYPE;
        } else if (mTypeStr.equals("leave_list")) {
            return LEAVE_LIST_MESSAGE_TYPE;
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
