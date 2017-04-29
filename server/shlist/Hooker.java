package shlist;

import java.io.IOException;
import java.net.ServerSocket;
import java.util.concurrent.ExecutorService;

// Shutdown Hook
// kills resources if we get ctrl-c
// should close DB and sockets and whatnot
// output something to the log file?
public class Hooker extends Thread {
	private ServerSocket ss;
	private ExecutorService exec;
	
	public void run() {
		System.out.println("");
		try {
			ss.close();
		} catch (IOException e) {
			e.printStackTrace();
		}
		exec.shutdown();
		while (!exec.isTerminated()) { }
		System.out.println("Clean Exit");
	}
	
	public Hooker(ServerSocket ss, ExecutorService exec) {
		this.ss = ss;
		this.exec = exec;
	}
}
