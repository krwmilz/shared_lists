package ca.absentmindedproductions.shlist;

import android.Manifest;
import android.content.Context;
import android.content.pm.PackageManager;
import android.support.v4.app.ActivityCompat;
import android.support.v4.content.ContextCompat;
import android.support.v7.app.AppCompatActivity;
import android.os.Bundle;
import android.support.v7.widget.Toolbar;
import android.telephony.TelephonyManager;
import android.util.Log;
import android.view.View;

public class HomeScreen extends AppCompatActivity {
    private final int PORT = 5437;
    private final String SERVER_ADDRESS = "104.236.186.39";
    Bundle sis;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_home_screen);
        sis = savedInstanceState;

        Toolbar myToolbar = (Toolbar) findViewById(R.id.my_toolbar);
        setSupportActionBar(myToolbar);

        if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_PHONE_STATE) != PackageManager.PERMISSION_GRANTED)
        {
            ActivityCompat.requestPermissions(this, new String[]{Manifest.permission.READ_PHONE_STATE}, 1);
        } else {
            startFragments(savedInstanceState, true);
        }
    }

    public void startFragments(Bundle savedInstanceState, boolean networkMode) {
        if (savedInstanceState != null) {
            return;
        }

        if (findViewById(R.id.current_fragment) != null) {
            CurrentFragment cFrag = new CurrentFragment();
            cFrag.setArguments(getIntent().getExtras());
            getSupportFragmentManager().beginTransaction().add(R.id.current_fragment, cFrag).commit();
            findViewById(R.id.current_fragment).setVisibility(View.VISIBLE);
        }

        if (findViewById(R.id.available_fragment) != null && networkMode) {
            AvailableFragment aFrag = new AvailableFragment();
            aFrag.setArguments(getIntent().getExtras());
            getSupportFragmentManager().beginTransaction().add(R.id.available_fragment, aFrag).commit();
            findViewById(R.id.available_fragment).setVisibility(View.VISIBLE);

            TelephonyManager tMgr = (TelephonyManager)getSystemService(Context.TELEPHONY_SERVICE);
            String mPhoneNumber = tMgr.getLine1Number();
            long phoneNum = Long.parseLong(mPhoneNumber.substring(2));
            new SendMessage().execute(SERVER_ADDRESS, Integer.toString(PORT), Long.toString(phoneNum));
        }
    }

    @Override
    public void onRequestPermissionsResult(int requestCode,
                                           String permissions[], int[] grantResults) {
        switch (requestCode) {
            case 1: {
                if (grantResults.length > 0
                        && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                    startFragments(sis, true);
                } else {
                    startFragments(sis, false);
                }
                return;
            }
        }
    }
}
