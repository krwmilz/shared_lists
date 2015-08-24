package drsocto.shlist;

import android.content.Context;
import android.content.Intent;
import android.database.Cursor;
import android.provider.ContactsContract;
import android.support.v7.app.ActionBarActivity;
import android.os.Bundle;
import android.util.Log;
import android.view.LayoutInflater;
import android.view.Menu;
import android.view.MenuItem;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ArrayAdapter;
import android.widget.Button;
import android.widget.CheckBox;
import android.widget.ListView;
import android.widget.TextView;

import java.util.ArrayList;


public class ContactsScreen extends ActionBarActivity {

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.layout_contacts_screen);

        ArrayList<String> list = new ArrayList<String>();
        ListView lv = (ListView) findViewById(R.id.contactList);

        Cursor phones = getContentResolver().query(ContactsContract.CommonDataKinds.Phone.CONTENT_URI, null,null,null, null);
        while (phones.moveToNext())
        {
            String name=phones.getString(phones.getColumnIndex(ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME));
            String phoneNumber = phones.getString(phones.getColumnIndex(ContactsContract.CommonDataKinds.Phone.NUMBER));
            list.add(name + ": " + phoneNumber);

        }
        phones.close();
        ArrayAdapter<String> adapter = new MyCustomAdapter(this, R.layout.contact_row, list);
        lv.setAdapter(adapter);
    }


    @Override
    public boolean onCreateOptionsMenu(Menu menu) {
        // Inflate the menu; this adds items to the action bar if it is present.
        getMenuInflater().inflate(R.menu.menu_contacts_screen, menu);
        return true;
    }

    public void listPage(View v) {
        finish();
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
        }

        return super.onOptionsItemSelected(item);
    }

    private class MyCustomAdapter extends ArrayAdapter<String> {

        private ArrayList<String> taskList;

        public MyCustomAdapter(Context context, int textViewResourceId,
                               ArrayList<String> taskList) {
            super(context, textViewResourceId, taskList);
            this.taskList = new ArrayList<String>();
            this.taskList.addAll(taskList);
        }

        private class ViewHolder {
            CheckBox cBox;
        }

        @Override
        public View getView(final int position, View convertView, ViewGroup parent) {

            ViewHolder viewHolder = null;
            Log.v("ConvertView", String.valueOf(position));

            if (convertView == null) {
                LayoutInflater inflater = (LayoutInflater)getSystemService(Context.LAYOUT_INFLATER_SERVICE);
                convertView = inflater.inflate(R.layout.contact_row, null);

                viewHolder = new ViewHolder();
                viewHolder.cBox = (CheckBox) convertView.findViewById(R.id.contactCheckBox);
                convertView.setTag(viewHolder);

                viewHolder.cBox.setOnClickListener( new View.OnClickListener() {
                    public void onClick(View v) {
                        CheckBox taskCB = (CheckBox) v;
                        if (taskCB.isChecked())
                            Log.d("User Input: ", "Checked " + taskCB.getText());
                        else
                            Log.d("User Input: ", "Un-Checked " + taskCB.getText());
                    }
                });
            }
            else {
                viewHolder = (ViewHolder) convertView.getTag();
            }

            String task = taskList.get(position);
            viewHolder.cBox.setText(task);

            return convertView;

        }

    }
}
