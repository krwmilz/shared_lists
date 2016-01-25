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
import android.widget.CheckBox;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.ListView;
import android.widget.TextView;
import android.widget.Toast;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;
import org.w3c.dom.Text;

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
    private ArrayList<Shlist> list1;
    private ArrayList<String> list1_str;
    private MyInListsAdapter adapter1;
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
            JSONObject obj = new JSONObject();
            try {
                obj.put("phone_number", "" + phoneNum);
                obj.put("os", "android");
            } catch (JSONException e) {
                Log.d("netman", "JSONException: " + e);
            }
            String message = obj.toString();
            AsyncTask sndmt = new sendNewDeviceMessageTask().execute(message, "" + MsgTypes.device_add);
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

        list1 = new ArrayList<Shlist>();
        list1_str = new ArrayList<String>();

        adapter1 = new MyInListsAdapter(this, R.layout.list_row, list1, list1_str);

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
            JSONObject obj = new JSONObject();
            try {
                obj.put("device_id", "" + id);
                new sendGetListsMessageTask().execute(obj.toString(), "" + MsgTypes.lists_get);
            } catch (JSONException e) {
                Log.d("netman", "JSON Exception: " + e);
            }
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
                Shlist list_entry = adapter1.getShlist(position);
                int num = list_entry.getNum();
                Log.d("main", "Tried to leave list: " + list_entry);
                JSONObject obj = new JSONObject();
                try {
                    obj.put("device_id", "" + id);
                    obj.put("list_num", num);
                } catch (JSONException e) {
                    Log.d("netman", "JSON Exception: " + e);
                }
                new sendLeaveListMessageTask().execute(obj.toString(), "" + MsgTypes.list_leave);
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
        String message = "";
        dbHelper.closeDB();
        try {
            JSONObject list_obj = new JSONObject();
            list_obj.put("name", name.trim());
            list_obj.put("date", System.currentTimeMillis() / 1000L);
            JSONObject main_obj = new JSONObject();
            main_obj.put("device_id", device_id);
            main_obj.put("list", list_obj);
            message = main_obj.toString();
        } catch (JSONException e) {
            Log.d("netman", "JSONException: " + e);
        }
        new sendNewListMessageTask().execute(message, "" + MsgTypes.list_add);
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
            //list1.add(joinLeaveMessage);
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
            list1.remove(joinLeavePosition);
            list1_str.remove(joinLeavePosition);
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
            try {
                JSONObject main_obj = new JSONObject(result);
                int num = main_obj.getInt("num_lists");
                JSONArray lists_arr = main_obj.getJSONArray("lists");
                Shlist temp_shlist;
                JSONObject temp_json;
                int temp_items[] = new int[2];

                for (int i = 0; i < num; ++i) {
                    temp_json = lists_arr.getJSONObject(i);
                    temp_items[0] = temp_json.getInt("items_complete");
                    temp_items[1] = temp_json.getInt("items_total");
                    temp_shlist = new Shlist(temp_json.getInt("num"), temp_json.getString("name"), temp_items, new String[1], 22);
                    list1.add(temp_shlist);
                    list1_str.add(temp_shlist.getName());
                }

                cListsTV.setText("Current Lists (" + list1.size() + ")");
                adapter1.notifyDataSetChanged();
            } catch (JSONException e) {
                Log.d("netman", "JSON Exception: " + e);
            }
        }
    }

    public class sendFriendAddMessage extends AsyncTask<String, Void, String> {
        @Override
        protected String doInBackground(String... urls) {
            String result = nm.sendMessage(urls);
            return result;
        }

        @Override
        protected void onPostExecute(String result) {

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
            try {
                JSONObject main_obj = new JSONObject(result);
                JSONObject list_obj = main_obj.getJSONObject("list");
                int list_num = list_obj.getInt("num");
                String list_num_str = list_obj.getString("num");
                String list_name = list_obj.getString("name");
                int date = list_obj.getInt("date");
                int items[] = new int[2];
                items[0] = list_obj.getInt("items_complete");
                items[1] = list_obj.getInt("items_total");
                int num_members = list_obj.getInt("num_members");
                String[] members = new String[0];
                Shlist shlist = new Shlist(list_num, list_name, date);
                dbHelper.openOrCreateDB();
                dbHelper.addList(list_num_str, list_name);
                dbHelper.closeDB();
                list1.add(shlist);
                list1_str.add(shlist.getName());
                cListsTV.setText("Current Lists (" + list1.size() + ")");
                adapter1.notifyDataSetChanged();
            } catch (JSONException e) {
                Log.d("netman", "JSON Exception: " + e);
            }
        }
    }

    private class MyInListsAdapter extends ArrayAdapter<String> {

        private ArrayList<Shlist> ourLists;

        public MyInListsAdapter(Context context, int textViewResourceId,
                               ArrayList<Shlist> taskList, ArrayList<String> stringList) {
            super(context, textViewResourceId, stringList);
            ourLists = taskList;
        }

        private class ViewHolder {
            Shlist shlist;
            TextView name;
            TextView completion;
            TextView friends;
        }

        public Shlist getShlist(int position) {
            return ourLists.get(position);
        }

        @Override
        public View getView(final int position, View convertView, ViewGroup parent) {

            ViewHolder viewHolder = null;
            Log.v("ConvertView", String.valueOf(position));

            if (convertView == null) {
                LayoutInflater inflater = (LayoutInflater)getSystemService(Context.LAYOUT_INFLATER_SERVICE);
                convertView = inflater.inflate(R.layout.list_row, null);

                viewHolder = new ViewHolder();
                viewHolder.name = (TextView) convertView.findViewById(R.id.list_name);
                viewHolder.completion = (TextView) convertView.findViewById(R.id.list_completion);
                viewHolder.friends = (TextView) convertView.findViewById(R.id.friends_list);

                convertView.setTag(viewHolder);

            }
            else {
                viewHolder = (ViewHolder) convertView.getTag();
            }

            viewHolder.shlist = ourLists.get(position);
            viewHolder.name.setText(viewHolder.shlist.getName());
            viewHolder.completion.setText(viewHolder.shlist.getComplete() + "/" + viewHolder.shlist.getTotal());
            viewHolder.friends.setText("Kyle Muthafuckin Milz");

            return convertView;

        }

    }
}
