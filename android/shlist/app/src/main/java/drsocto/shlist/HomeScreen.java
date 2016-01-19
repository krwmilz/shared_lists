package drsocto.shlist;

import android.app.AlertDialog;
import android.content.Context;
import android.content.DialogInterface;
import android.content.Intent;
import android.database.Cursor;
import android.graphics.Canvas;
import android.os.AsyncTask;
import android.provider.ContactsContract;
import android.support.v7.app.ActionBarActivity;
import android.os.Bundle;
import android.telephony.TelephonyManager;
import android.util.Log;
import android.view.ContextMenu;
import android.view.Display;
import android.view.LayoutInflater;
import android.view.Menu;
import android.view.MenuInflater;
import android.view.MenuItem;
import android.view.View;
import android.view.ViewGroup;
import android.widget.AdapterView;
import android.widget.ArrayAdapter;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.ListView;
import android.widget.TextView;
import android.widget.Toast;

import java.nio.ByteBuffer;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.TimeoutException;

// TODO: How do we preserve the local db on uninstall?
// We could just save device id for reinstalls and have
// server update lists on next run. Prompt user!

public class HomeScreen extends ActionBarActivity {

    public final static String SELECTED_LIST = "drsocto.shlist.SELECTED_LIST";

    private final String DEBUG_TAG = "PIMPJUICE";
    private final String SERVER_ADDRESS = "104.236.186.39";
    private final int SERVER_PORT = 5437;
    private final String dbName = "shlist.db";
    private ArrayList<String> list1;
    private ArrayAdapter<String> adapter1;
    private ArrayAdapter<String> adapter2;
    private ArrayList<String> list2;
    private long phoneNum;
    private String id;
    private String mPhoneNumber;
    private TextView cListsTV;
    private TextView oListsTV;
    private String joinLeaveMessage;
    private int joinLeavePosition;
    NetMan nm;
    DBHelper dbHelper;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.layout_home_screen);

        dbHelper = new DBHelper(dbName, this);
        //dbHelper.deleteDB();
        dbHelper.openOrCreateDB();

        nm = new NetMan(SERVER_ADDRESS, SERVER_PORT, this);

        TelephonyManager tMgr = (TelephonyManager) this.getSystemService(Context.TELEPHONY_SERVICE);
        mPhoneNumber = tMgr.getLine1Number().substring(2);
        //Log.d("HomeScreen", "Phone Number: " + mPhoneNumber);
        // remove '+' before parsing
        phoneNum = Long.parseLong(mPhoneNumber);
        //dbHelper.setDeviceID("lHWisR7leI1DmQQ9GlEgXODeeE7LAyFlpIHCcX1dNRI", mPhoneNumber);
        id = dbHelper.getDeviceID();

        Log.d("netman", "id is: " + id);

        dbHelper.closeDB();

        if (id == null) {
            String message = phoneNum + "\0android";
            AsyncTask sndmt = new sendNewDeviceMessageTask().execute(message, "" + MsgTypes.DEVICE_ADD_TYPE);
            try {
                sndmt.get(1000, TimeUnit.MILLISECONDS);
            } catch (InterruptedException e) {
                e.printStackTrace();
            } catch (ExecutionException e) {
                e.printStackTrace();
            } catch (TimeoutException e) {
                e.printStackTrace();
            }
        }

        list1 = new ArrayList<String>();

        adapter1 = new ArrayAdapter<String>(this, R.layout.list_row, R.id.list_name, list1);

        ListView lv1 = (ListView) findViewById(R.id.currentLists);
        registerForContextMenu(lv1);

        list2 = new ArrayList<String>();

        adapter2 = new ArrayAdapter<String>(this, R.layout.list_row, R.id.list_name, list2);

        ListView lv2 = (ListView) findViewById(R.id.openLists);

        cListsTV = (TextView) findViewById(R.id.currentListsTV);
        oListsTV = (TextView) findViewById(R.id.openListsTV);

        cListsTV.setText("Current Lists (" + list1.size() + ")");
        oListsTV.setText("Available Lists (" + list2.size() + ")");

        lv1.setAdapter(adapter1);
        lv2.setAdapter(adapter2);

        lv1.setOnItemClickListener(new AdapterView.OnItemClickListener() {
            @Override
            public void onItemClick(AdapterView<?> parent, View view, int position, long posid) {
                /*String text = adapter1.getItem(position);
                Log.d("lv1", "Clicked: " + text);
                String[] nameID = text.split(":");
                String message = id + "\0" + nameID[1];
                new sendLeaveListMessageTask().execute(message, "leave_list");
                joinLeaveMessage = text;
                joinLeavePosition = position;*/
                listPage(adapter1.getItem(position));
            }
        });

        lv2.setOnItemClickListener(new AdapterView.OnItemClickListener() {
            @Override
            public void onItemClick(AdapterView<?> parent, View view, int position, long posid) {
                String text = adapter2.getItem(position);
                Log.d("lv2", "Clicked: " + text);
                String[] nameID = text.split(":");
                String message = id + "\0" + nameID[1];
                new sendJoinListMessageTask().execute(message, "join_list");
                joinLeaveMessage = text;
                joinLeavePosition = position;
            }
        });

        if (id != null) {
            new sendGetListsMessageTask().execute(id, "" + MsgTypes.GET_LISTS_TYPE);
        }


        /* if device id doesn't exist
            get phone number
            send to server
            TODO: if phone number already exists, verify contacts,
            TODO: resend device id, or reroll id and wipe out references
            get device id
            write device id locally


         */
        // We can get around the new phone thing, if you reinstall the app, we force it to reload contacts


        // create and fill current lists

        // create and fill available lists
    }


    @Override
    public boolean onCreateOptionsMenu(Menu menu) {
        // Inflate the menu; this adds items to the action bar if it is present.
        getMenuInflater().inflate(R.menu.menu_home_screen, menu);
        return true;
    }

    @Override
    public void onCreateContextMenu(ContextMenu menu, View v, ContextMenu.ContextMenuInfo menuInfo) {
        super.onCreateContextMenu(menu, v, menuInfo);
        MenuInflater inflater = getMenuInflater();
        inflater.inflate(R.menu.context_menu_home_screen, menu);
    }

    @Override
    public boolean onContextItemSelected(MenuItem item) {
        AdapterView.AdapterContextMenuInfo info = (AdapterView.AdapterContextMenuInfo) item.getMenuInfo();
        switch (item.getItemId()) {
            case R.id.leave_list:
                int position = (int) info.id;
                joinLeavePosition = position;
                String list_entry = adapter1.getItem(position);
                Log.d("main", "Tried to leave list: " + list_entry);
                String list_entry_split[] = list_entry.split(":");
                String list_name = list_entry_split[0];
                String list_id = list_entry_split[1];
                String device_id = id;
                String message = device_id + "\0" + list_id;
                new sendLeaveListMessageTask().execute(message, "" + MsgTypes.LEAVE_LIST_TYPE);
                return true;
            default:
                return super.onContextItemSelected(item);
        }
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
        } else if (id == R.id.action_add) {
            addListDialog();
        } else if(id == R.id.delete_db) {
            dbHelper.deleteDB();
        } else if(id == R.id.action_contacts) {
            contactsPage();
        }

        return super.onOptionsItemSelected(item);
    }

    public void removeDB(View v) {
        dbHelper.deleteDB();
    }

    public void listPage(String name) {
        Intent intent = new Intent(this, ListScreen.class);
        intent.putExtra(SELECTED_LIST, name);
        startActivity(intent);
    }

    public void contactsPage() {
        Intent intent = new Intent(this, ContactsScreen.class);
        startActivity(intent);
    }

    public void addList(String name) {
        dbHelper.openOrCreateDB();
        String device_id = dbHelper.getDeviceID();
        dbHelper.closeDB();
        String message = device_id + "\0" + name;
        new sendNewListMessageTask().execute(message, "" + MsgTypes.ADD_LIST_TYPE);
        // send pair to server
        // get list id message
        // create list item, add list item
    }

    public void addListDialog() {
        LayoutInflater inflater = (LayoutInflater) getSystemService(LAYOUT_INFLATER_SERVICE);
        View layout = inflater.inflate(R.layout.add_list_prompt, (ViewGroup) findViewById(R.id.addListPromptLayout));
        AlertDialog.Builder builder = new AlertDialog.Builder(this);
        builder.setView(layout);
        builder.setTitle("New List");
        final EditText nameBox = (EditText) layout.findViewById(R.id.userInput);

        builder.setPositiveButton("Add", new DialogInterface.OnClickListener() {
            @Override
            public void onClick(DialogInterface dialogInterface, int i) {
                addList(nameBox.getText().toString());
                dialogInterface.dismiss();
            }
        });

        builder.setNegativeButton("Cancel", new DialogInterface.OnClickListener() {
            @Override
            public void onClick(DialogInterface dialogInterface, int i) {
                dialogInterface.dismiss();
            }
        });
        AlertDialog dialog = builder.create();

        dialog.show();
    }

    public class sendNewDeviceMessageTask extends AsyncTask<String, Void, String> {
        @Override
        protected String doInBackground(String... urls) {
            Log.d("NetMan", "New Device Start");
            String result = nm.sendMessage(urls);
            return result;
        }
        @Override
        protected void onPostExecute(String result) {
            if (result.compareTo("failed") != 0) {
                dbHelper.openOrCreateDB();
                dbHelper.setDeviceID(result, mPhoneNumber);
                dbHelper.closeDB();
                id = mPhoneNumber;
            }
            //TextView tv = (TextView) findViewById(R.id.deviceID);
            //tv.setText("Device ID (From Server): " + result + " Phone Number: " + phoneNum);
            Log.d("NetMan", "New Device End");
        }
    }

    public class sendJoinListMessageTask extends AsyncTask<String, Void, String> {
        @Override
        protected String doInBackground(String... urls) {
            Log.d("NetMan", "Join List Start");
            String result = nm.sendMessage(urls);
            return result;
        }
        @Override
        protected void onPostExecute(String result) {
            Log.d("NetMan", "Join List End");
            list1.add(joinLeaveMessage);
            list2.remove(joinLeavePosition);
            adapter1.notifyDataSetChanged();
            adapter2.notifyDataSetChanged();
            cListsTV.setText("Current Lists (" + list1.size() + ")");
            oListsTV.setText("Available Lists (" + list2.size() + ")");
        }
    }

    public class sendLeaveListMessageTask extends AsyncTask<String, Void, String> {
        @Override
        protected String doInBackground(String... urls) {
            Log.d("NetMan", "Leave List Start");
            String result = nm.sendMessage(urls);
            return result;
        }
        @Override
        protected void onPostExecute(String result) {
            /*result = result.substring(4);
            String[] parts = result.split("\0");
            Log.d("NetMan", "List id: " + parts[0]);
            Log.d("NetMan", "Alive: " + parts[1]);
            Log.d("NetMan", "Leave List End");
            if (parts[1].equals("1")) {
                list2.add(joinLeaveMessage);
            }*/
            list1.remove(joinLeavePosition);
            adapter1.notifyDataSetChanged();
            adapter2.notifyDataSetChanged();
            cListsTV.setText("Current Lists (" + list1.size() + ")");
            oListsTV.setText("Available Lists (" + list2.size() + ")");
        }
    }

    public class sendGetListsMessageTask extends AsyncTask<String, Void, String> {
        @Override
        protected String doInBackground(String... urls) {
            Log.d("NetMan", "Get Lists Start");
            String result = nm.sendMessage(urls);
            return result;
        }
        @Override
        protected void onPostExecute(String result) {
            String lists[] = result.split("\n");
            for (int i = 0; i < lists.length; ++i) {
                Log.d("netman", "List: " + lists[i]);
                String list_split[] = lists[i].split("\0");
                if (list_split.length > 1) {
                    String list_name = list_split[1];
                    list1.add(list_name + ":" + list_split[0]);
                }
            }
            cListsTV.setText("Current Lists (" + list1.size() + ")");
            adapter1.notifyDataSetChanged();
        }
    }

    public class sendNewListMessageTask extends AsyncTask<String, Void, String> {
        @Override
        protected String doInBackground(String... urls) {
            String result = nm.sendMessage(urls);
            return result;
        }
        @Override
        protected void onPostExecute(String result) {
            String results[] = result.split("\0");
            String list_id = results[0];
            String list_name = results[1];
            dbHelper.openOrCreateDB();
            dbHelper.addList(list_id, list_name);
            dbHelper.closeDB();
            list1.add(list_name + ":" + list_id);
            cListsTV.setText("Current Lists (" + list1.size() + ")");
            adapter1.notifyDataSetChanged();
        }
    }
}
