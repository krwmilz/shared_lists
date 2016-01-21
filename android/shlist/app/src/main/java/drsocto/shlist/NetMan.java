package drsocto.shlist;

import android.content.Context;
import android.os.AsyncTask;
import android.util.JsonReader;
import android.util.Log;

import org.json.JSONException;
import org.json.JSONObject;

import java.io.BufferedReader;
import java.io.BufferedWriter;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.OutputStreamWriter;
import java.io.PrintWriter;
import java.net.Socket;
import java.net.UnknownHostException;
import java.nio.ByteBuffer;

import javax.net.SocketFactory;
import javax.net.ssl.SSLSocket;
import javax.net.ssl.SSLSocketFactory;

/**
 * Created by David on 7/12/2015.
 */
public class NetMan {
    private String addr;
    private int port;
    SocketFactory sf = SSLSocketFactory.getDefault();
    SSLSocket socket;
    Context context;

    public NetMan(String addr, int port, Context theContext) {
        this.addr = addr;
        this.port = port;
        context = theContext;
    }

    public int openSocket() {
        try {
            socket = (SSLSocket) sf.createSocket(addr, port);
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

    public String sendMessage(String[] args) {
        // Setup Header
        int mType = Integer.parseInt(args[1]);
        String message = args[0];
        Log.d("NetMan", "In sendMessage");
        Log.d("NetMan", "First Type: " + mType);
        Log.d("NetMan", "Message: " + message + " | Type: " + mType);
        byte[] version = toByteArray(MsgTypes.protocol_version);
        byte[] type = toByteArray(mType);
        byte[] length = toByteArray(message.length());
        // Send Message
        if (openSocket() == 0) {
            try {
                Log.d("NetMan", "In socket open");
                PrintWriter out = new PrintWriter(new BufferedWriter(new OutputStreamWriter(socket.getOutputStream())), true);

                socket.getOutputStream().write(version);
                socket.getOutputStream().write(type);
                socket.getOutputStream().write(length);
                out.print(message);
                out.flush();

                InputStream in = socket.getInputStream();
                int count = in.read(version);
                count = in.read(type);
                count = in.read(length);

                int vInt = fromByteArray(version);
                int tInt = fromByteArray(type);
                int lInt = fromByteArray(length);

                Log.d("NetMan", "Header Read");
                Log.d("NetMan", "Version: " + vInt + " | Type: " + tInt + " | Length: " + lInt);

                BufferedReader br = new BufferedReader(new InputStreamReader(socket.getInputStream()));

                char[] response = new char[lInt];
                Log.d("NetMan", "Message Length: " + response.length);
                count = br.read(response);

                String response_str = "";

                for (int i = 0; i < response.length; ++i) {
                    response_str += response[i];
                }

                Log.d("netman", "Response: " + response_str);


                if (!response_str.isEmpty()) {
                    JSONObject obj;
                    String status;
                    try {
                        obj = new JSONObject(response_str);
                        status = obj.getString("status");
                        Log.d("netman", "Parsed JSON, status: " + status);
                        if (status.equalsIgnoreCase("ok")) {
                            switch (mType) {
                                case MsgTypes.device_add:
                                    closeSocket();
                                    return obj.getString("device_id");
                                case MsgTypes.list_add:
                                    closeSocket();
                                    return obj.toString();
                                case MsgTypes.lists_get:
                                    closeSocket();
                                    return obj.toString();
                            }
                        } else {
                            Log.d("netman", "Error:" + obj.toString());
                        }
                    } catch (JSONException e) {
                        Log.d("netman", "JSONException: " + e);
                    }
                } else {
                    Log.d("netman", "Error: empty payload");
                }

            } catch (java.io.IOException e) {
                Log.d("NetMan", "Exception: " + e);
            }
            closeSocket();
        }
        return "failed";
    }

    public static int fromByteArray(byte[] bytes) {
        return (bytes[0] & 0xFF) << 8 | (bytes[1] & 0xFF);
    }

    public static byte[] toByteArray(long value)
    {
        byte[] ret = new byte[2];
        ret[1] = (byte) ((value >> ((0)*8) & 0xFF));
        ret[0] = (byte) ((value >> ((1)*8) & 0xFF));
        return ret;
    }
}
