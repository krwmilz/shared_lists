package drsocto.shlist;

import android.content.Context;
import android.database.Cursor;
import android.database.sqlite.SQLiteDatabase;
import android.util.Log;

/**
 * Created by David on 7/12/2015.
 */
public class DBHelper {
    private String dbName;
    private SQLiteDatabase theDB;
    private Context theContext;

    public DBHelper(String name, Context context) {
        dbName = name;
        theContext = context;
    }

    public void openOrCreateDB() {
        theDB = theContext.openOrCreateDatabase(dbName, theContext.MODE_PRIVATE, null);
        theDB.execSQL("CREATE TABLE IF NOT EXISTS device(id VARCHAR not null, phone_number int not null)");
        theDB.execSQL("CREATE TABLE IF NOT EXISTS my_lists(id VARCHAR not null, name VARCHAR not null, date int)");
        // TODO: create the rest of the tables here as well, can we check the return of that command?
        // ie if that creates the table then create everything else? Or should we create when the tables are new.
    }

    public void deleteDB() { theContext.deleteDatabase(dbName);  }

    public void closeDB() {
        theDB.close();
    }

    public String getDeviceID() {
        Cursor resultSet = theDB.rawQuery("SELECT id FROM device", null);
        if(resultSet.moveToFirst()) {
            Log.i("DBHelper", "Returning a value from getDeviceID()");
            return resultSet.getString(resultSet.getColumnIndex("id"));
        } else {
            Log.i("DBHelper", "Returning empty string from getDeviceID()");
            return null;
        }
    }

    public void setDeviceID(String deviceID, String phoneNumber) {
        Log.d("DBHelper", "Added Entry To device: " + deviceID + " - " + phoneNumber);
        String query = "insert into device VALUES(?,?)";
        theDB.execSQL(query, new String[] {deviceID, phoneNumber});
    }

    public void addList(String listID, String listName) {
        Log.d("dbhelper", "Added Entry To My Lists: " + listID + " - " + listName);
        String query = "insert into my_lists VALUES(?,?,?)";
        theDB.execSQL(query, new String[] {listID, listName, ""});
    }

}
