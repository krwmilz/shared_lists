package shlist;

import java.io.IOException;
import java.net.ServerSocket;
import java.net.Socket;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public class Server {
	
	public final static int THREAD_COUNT = 4;
	public final static int PORT = 5437;
	
	public static void main(String[] args) {
		
		ExecutorService exec = Executors.newFixedThreadPool(THREAD_COUNT);
		
		ServerSocket sSock = null;
		Socket sock = null;
		
		try {
			sSock = new ServerSocket(PORT);
		} catch (IOException e) {
			e.printStackTrace();
		}
		
		// Add the runtime hook, for ctrl+c
		Runtime r = Runtime.getRuntime();
		r.addShutdownHook(new Hooker(sSock, exec));
		
		while (true) {
			try {
				sock = sSock.accept();
			} catch (IOException e) {
					//System.out.println("IO Error: " + e);
					break;
			}
			exec.execute(new Worker(sock));
		}
	}
}
