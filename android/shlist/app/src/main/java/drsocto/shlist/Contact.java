package drsocto.shlist;

/**
 * Created by dreng on 1/24/2016.
 */
public class Contact {
    private String number;
    private String name;
    private boolean selected = false;

    public Contact(String name, String number) {
        this.number = number;
        this.name = name;
    }

    public Contact(String name, String number, boolean checked) {
        this.name = name;
        this.number = number;
        this.selected = checked;
    }

    public String getName() {
        return name;
    }

    public String getNumber() {
        return number;
    }

    public boolean getSelected() {
        return selected;
    }

    public void setSelected(boolean value) {
        selected = value;
    }
}
