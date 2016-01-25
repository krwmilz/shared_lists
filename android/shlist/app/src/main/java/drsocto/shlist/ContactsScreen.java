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
import java.util.regex.Matcher;
import java.util.regex.Pattern;


public class ContactsScreen extends ActionBarActivity {

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.layout_contacts_screen);

        ArrayList<String> list = new ArrayList<String>();
        ArrayList<Boolean> list_bool = new ArrayList<Boolean>();
        ListView lv = (ListView) findViewById(R.id.contactList);

        ArrayList<Contact> contacts_list = new ArrayList<Contact>();

        Cursor phones = getContentResolver().query(ContactsContract.CommonDataKinds.Phone.CONTENT_URI, null,null,null, null);
        while (phones.moveToNext())
        {
            String name = phones.getString(phones.getColumnIndex(ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME));
            String phoneNumber = phones.getString(phones.getColumnIndex(ContactsContract.CommonDataKinds.Phone.NUMBER));
            String pattern = "(\\d*)";
            Pattern r = Pattern.compile(pattern);
            Matcher m = r.matcher(phoneNumber);
            String out = "";
            while(m.find()) {
                out += m.group(1);
            }
            if (out.length() == 11) {
                out = out.substring(1);
            }
            Log.d("contacts", "Regex: " + out);
            phoneNumber = out;

            Contact contact = new Contact(name, phoneNumber);
            contacts_list.add(contact);
            list.add(name);
        }
        phones.close();
        MyContactsListsAdapter adapter = new MyContactsListsAdapter(this, R.id.contactCheckBox, contacts_list, list);
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

    private class MyContactsListsAdapter extends ArrayAdapter<String> {

        private ArrayList<Contact> contacts;

        public MyContactsListsAdapter(Context context, int textViewResourceId,
                                ArrayList<Contact> taskList, ArrayList<String> stringList) {
            super(context, textViewResourceId, stringList);
            contacts = taskList;
        }

        private class ViewHolder {
            Contact shlist;
            CheckBox name;
        }

        public Contact getContact(int position) {
            return contacts.get(position);
        }

        @Override
        public View getView(final int position, View convertView, ViewGroup parent) {

            ViewHolder viewHolder = null;
            Log.v("ConvertView", String.valueOf(position));

            if (convertView == null) {
                LayoutInflater inflater = (LayoutInflater)getSystemService(Context.LAYOUT_INFLATER_SERVICE);
                convertView = inflater.inflate(R.layout.contact_row, null);

                viewHolder = new ViewHolder();


                convertView.setTag(viewHolder);

            }
            else {
                viewHolder = (ViewHolder) convertView.getTag();
            }

            viewHolder.shlist = contacts.get(position);
            viewHolder.name = (CheckBox) convertView.findViewById(R.id.contactCheckBox);
            viewHolder.name.setText(viewHolder.shlist.getName());
            viewHolder.name.setChecked(viewHolder.shlist.getSelected());
            final Contact contact = viewHolder.shlist;
            viewHolder.name.setOnClickListener(new View.OnClickListener() {
                @Override
                public void onClick(View v) {
                    Log.d("contacts", "Clicked: " + contact.getName() + ":" + contact.getNumber());
                    if (contact.getSelected()) {
                        contact.setSelected(false);
                    } else {
                        contact.setSelected(true);
                    }
                }
            });

            return convertView;

        }

    }
}
