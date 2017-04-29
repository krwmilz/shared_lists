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
        	e.printStackTrace();
            return;
        }
        System.out.println("Started new thread");
        String line;
        while (true) {
            try {
                line = brinp.readLine();
                if (line != null) {
                	System.out.println(line);
                } else {
                	sock.close();
                	brinp.close();
                	System.out.println("Closing Socket");
                	break;
                }
            } catch (IOException e) {
                e.printStackTrace();
                return;
            }
        }
        System.out.println("Exiting Thread");
	}
}
