package drsocto.shlist;

import android.content.Context;
import android.content.Intent;
import android.support.v7.app.ActionBarActivity;
import android.os.Bundle;
import android.util.Log;
import android.view.LayoutInflater;
import android.view.Menu;
import android.view.MenuItem;
import android.view.View;
import android.view.ViewGroup;
import android.widget.AdapterView;
import android.widget.ArrayAdapter;
import android.widget.CheckBox;
import android.widget.ListView;
import android.widget.Switch;
import android.widget.TextView;

import java.util.ArrayList;


public class ListScreen extends ActionBarActivity {
    ArrayList<String> list1;
    ArrayList<String> list1a;
    ArrayList<String> list1b;
    ArrayList<String> list2;

    ArrayAdapter<String> adapter1;
    ArrayAdapter<String> adapter2;

    TextView cListsTV;
    TextView oListsTV;


    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.layout_list_screen);

        Intent intent = getIntent();
        String listName = intent.getStringExtra(HomeScreen.SELECTED_LIST);

        setTitle(listName);

        // Shared items
        list1 = new ArrayList<String>();
        list1a = new ArrayList<String>();
        list1b = new ArrayList<String>();
        list1.add("Axe");
        list1a.add("4");
        list1b.add("Jeb");

        adapter1 = new MyCustomAdapter(this, R.layout.item_row, list1, list1a, list1b);

        ListView lv1 = (ListView) findViewById(R.id.sharedItems);

        list2 = new ArrayList<String>();
        list2.add("Space Muffins");

        adapter2 = new ArrayAdapter<String>(this, R.layout.item_row, R.id.itemName, list2);

        ListView lv2 = (ListView) findViewById(R.id.privateItems);
        lv2.setOnItemClickListener(new AdapterView.OnItemClickListener() {
            @Override
            public void onItemClick(AdapterView<?> parent, View view, int position, long id) {
                String name = adapter2.getItem(position);
                list2.remove(position);
                list1.add(name);
                adapter1.notifyDataSetChanged();
                adapter2.notifyDataSetChanged();
            }
        });

        cListsTV = (TextView) findViewById(R.id.sharedItemsTV);
        oListsTV = (TextView) findViewById(R.id.privateItemsTV);

        cListsTV.setText("Shared Items (" + list1.size() + ")");
        oListsTV.setText("Private Items (" + list2.size() + ")");

        lv1.setAdapter(adapter1);
        lv2.setAdapter(adapter2);
    }

    public void addListItem() {
        list2.add("Foobar");
        adapter2.notifyDataSetChanged();
    }

    @Override
    public boolean onCreateOptionsMenu(Menu menu) {
        // Inflate the menu; this adds items to the action bar if it is present.
        getMenuInflater().inflate(R.menu.menu_list_screen, menu);
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
        } if(id == R.id.action_add) {
            addListItem();
        }

        return super.onOptionsItemSelected(item);
    }




    private class MyCustomAdapter extends ArrayAdapter<String> {

        private ArrayList<String> nlist;
        private ArrayList<String> qlist;
        private ArrayList<String> olist;

        public MyCustomAdapter(Context context, int textViewResourceId,
                               ArrayList<String> nlist, ArrayList<String> qlist, ArrayList<String> olist) {
            super(context, textViewResourceId, nlist);
            this.nlist = new ArrayList<String>();
            this.nlist.addAll(nlist);
            this.olist = new ArrayList<String>();
            this.olist.addAll(olist);
            this.qlist = new ArrayList<String>();
            this.qlist.addAll(qlist);
        }

        private class ViewHolder {
            TextView name;
            TextView quantity;
            TextView owner;
            Switch complete;
        }

        @Override
        public View getView(final int position, View convertView, ViewGroup parent) {

            ViewHolder viewHolder = null;
            Log.v("ConvertView", String.valueOf(position));

            if (convertView == null) {
                LayoutInflater inflater = (LayoutInflater)getSystemService(Context.LAYOUT_INFLATER_SERVICE);
                convertView = inflater.inflate(R.layout.item_row, null);

                viewHolder = new ViewHolder();
                viewHolder.name = (TextView) convertView.findViewById(R.id.itemName);
                viewHolder.quantity = (TextView) convertView.findViewById(R.id.itemQuantity);
                viewHolder.owner = (TextView) convertView.findViewById(R.id.itemOwner);
                viewHolder.complete = (Switch) convertView.findViewById(R.id.itemComplete);
                convertView.setTag(viewHolder);

                viewHolder.name.setOnClickListener(new View.OnClickListener() {
                    @Override
                    public void onClick(View v) {
                        TextView tv = (TextView) v;
                        Log.d("User Input", "Clicked: " + tv.getText());
                    }
                });

                viewHolder.quantity.setOnClickListener(new View.OnClickListener() {
                    @Override
                    public void onClick(View v) {
                        TextView tv = (TextView) v;
                        Log.d("User Input", "Clicked: " + tv.getText());
                    }
                });

                viewHolder.owner.setOnClickListener(new View.OnClickListener() {
                    @Override
                    public void onClick(View v) {
                        TextView tv = (TextView) v;
                        Log.d("User Input", "Clicked: " + tv.getText());
                    }
                });

                viewHolder.complete.setOnClickListener(new View.OnClickListener() {
                    @Override
                    public void onClick(View v) {
                        Log.d("User Input", "Clicked: " + nlist.get(position) + "'s Checkbox");
                    }
                });
            }
            else {
                viewHolder = (ViewHolder) convertView.getTag();
            }

            String name = nlist.get(position);
            String quantity = qlist.get(position);
            String owner = olist.get(position);
            viewHolder.name.setText(name);
            viewHolder.quantity.setText("(x" + quantity +")");
            viewHolder.owner.setText(owner);

            return convertView;

        }

    }


}
