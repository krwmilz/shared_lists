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
import android.view.Display;
import android.view.LayoutInflater;
import android.view.Menu;
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
        String mPhoneNumber = tMgr.getLine1Number().substring(2);
        //Log.d("HomeScreen", "Phone Number: " + mPhoneNumber);
        // remove '+' before parsing
        phoneNum = Long.parseLong(mPhoneNumber);

        id = dbHelper.getDeviceID();

        dbHelper.closeDB();

        if (id == null) {
            AsyncTask sndmt = new sendNewDeviceMessageTask().execute(mPhoneNumber, "new_device");
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

        adapter1 = new ArrayAdapter<String>(this, R.layout.list_row, R.id.r_text, list1);

        ListView lv1 = (ListView) findViewById(R.id.currentLists);

        list2 = new ArrayList<String>();

        adapter2 = new ArrayAdapter<String>(this, R.layout.list_row, R.id.r_text, list2);

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
            new sendGetListsMessageTask().execute(id, "get_lists");
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
    public boolean onOptionsItemSelected(MenuItem item) {
        // Handle action bar item clicks here. The action bar will
        // automatically handle clicks on the Home/Up button, so long
        // as you specify a parent activity in AndroidManifest.xml.
        int id = item.getItemId();

        //noinspection SimplifiableIfStatement
        if (id == R.id.action_settings) {
            return true;
        } else if (id == R.id.action_add) {
            Log.d(DEBUG_TAG, "ADD PLAN CLICKED");
            addPlanDialog();
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
        new sendNewListMessageTask().execute(message, "new_list");
        // send pair to server
        // get list id message
        // create list item, add list item
    }

    public void addPlanDialog() {
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
            result = result.substring(4);
            String[] parts = result.split("\0");
            Log.d("NetMan", "List id: " + parts[0]);
            Log.d("NetMan", "Alive: " + parts[1]);
            Log.d("NetMan", "Leave List End");
            if (parts[1].equals("1")) {
                list2.add(joinLeaveMessage);
            }
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
            Log.d("NetMan", "Get Lists Done");
            result = result.substring(4);
            if (!result.equals("\0\0")) {
                Log.d("NetMan", "Got Response: " + result);
                String[] halves = result.split("\0\0");
                Log.d("NetMan", "halves size: " + halves.length);
                String[] cur_lists = halves[0].split("\0");
                if (halves.length > 1) {
                    String[] ava_lists = halves[1].split("\0");
                    for (int i = 0; i < ava_lists.length; ++i) {
                        String[] temp = ava_lists[i].split(":");
                        Log.d("NetMan", "-------------------");
                        Log.d("NetMan", "List (Available): " + (i+1));
                        Log.d("NetMan", "-------------------");
                        Log.d("NetMan", "Name: " + temp[0]);
                        list2.add(temp[0] + ":" + temp[1]);
                        Log.d("NetMan", "ID: " + temp[1]);
                        for (int j = 2; j < temp.length; ++j) {
                            Log.d("NetMan", "Member: " + temp[j]);
                        }
                    }
                }
                if (!cur_lists[0].equals("")) {
                    for (int i = 0; i < cur_lists.length; ++i) {
                        String[] temp = cur_lists[i].split(":");
                        Log.d("NetMan", "-------------------");
                        Log.d("NetMan", "List (Current): " + (i + 1));
                        Log.d("NetMan", "-------------------");
                        Log.d("NetMan", "Name: " + temp[0]);
                        Log.d("NetMan", "ID: " + temp[1]);
                        list1.add(temp[0] + ":" + temp[1]);
                        for (int j = 2; j < temp.length; ++j) {
                            Log.d("NetMan", "Member: " + temp[j]);
                        }
                    }
                }

                adapter1.notifyDataSetChanged();
                adapter2.notifyDataSetChanged();
                cListsTV.setText("Current Lists (" + list1.size() + ")");
                oListsTV.setText("Available Lists (" + list2.size() + ")");
            } else {
                Log.d("NetMan", "No Lists");
            }
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
            list1.add(result);
            cListsTV.setText("Current Lists (" + list1.size() + ")");
            adapter1.notifyDataSetChanged();
        }
    }
}