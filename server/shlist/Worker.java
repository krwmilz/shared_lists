package shlist;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.net.Socket;

public class Worker implements Runnable {
	private Socket sock;
	
	public Worker(Socket s) {
		this.sock = s;
	}
	
	public void run() {
		InputStream inp = null;
        BufferedReader brinp = null;
        try {
            inp = sock.getInputStream();
            brinp = new BufferedReader(new InputStreamReader(inp));
        } catch (IOException e) {
            return;
        }
        System.out.println("Started new thread");
        String line;
        try {
            line = brinp.readLine();
            if (line != null) {
            	System.out.println(line);
            }
        	sock.close();
        	brinp.close();
        	System.out.println("Closing Socket");
        } catch (IOException e) {
        	try {
	        	sock.close();
	        	brinp.close();
	        	System.out.println("Closing Socket");
        	} catch (IOException e1) {
        		e1.printStackTrace();
        	}
        }
        System.out.println("Exiting Thread");
	}
}
