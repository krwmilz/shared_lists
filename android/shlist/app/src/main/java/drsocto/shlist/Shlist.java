package drsocto.shlist;

/**
 * Created by dreng on 1/24/2016.
 */
public class Shlist {

    private int num;
    private String name;
    private int[] items = new int[2];

    private String[] member_list;
    private int members;

    private int date;


    // Constructors

    // New List
    public Shlist(int num, String name, int date) {
        this.num = num;
        this.name = name;
        this.date = date;
        this.items[0] = 0;
        this.items[1] = 0;
        this.members = 1;
    }

    // Existing List
    public Shlist(int num, String name, int[] items, String[] member_list, int date) {
        this.num = num;
        this.name = name;
        this.items = items;
        this.member_list = member_list;
        this.date = date;
        this.members = member_list.length;
    }

    public String getName() {
        return name;
    }

    public int getNum() {
        return num;
    }

    public int getComplete() {
        return items[0];
    }

    public int getTotal() {
        return items[1];
    }
}
