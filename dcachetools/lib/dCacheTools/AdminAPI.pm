package dCacheTools::AdminAPI;

use strict; 
use warnings;
use Carp;
use Time::HiRes qw/usleep/;

use BaseTools::ConfigReader;
use base 'Class::Singleton';

use Inline Java => "DATA";

sub _new_instance
{
  my ($this, $attr) = @_;
  my $class = ref $this || $this;

  my $reader = BaseTools::ConfigReader->instance();
  unless (defined $attr->{node}) {
    croak q|Admin node hostname is not specified even in the configuration file!|
      unless defined $reader->{config}{admin}{node};
    $attr->{node} = $reader->{config}{admin}{node};
  }
  $attr->{port}     = $reader->{config}{admin}{port} || 22223;
  $attr->{user}     = $reader->{config}{admin}{user} || q|admin|;
  $attr->{identity} = $reader->{config}{admin}{identity} || q|/root/.ssh/identity|;
  $attr->{debug}    = $reader->{config}{admin}{debug} unless defined $attr->{debug};

  bless { 
    _HANDLE => dCacheTools::AdminAPI::JAdmin->new($attr->{node}, 
                                                   $attr->{port}, 
                                                   $attr->{user}, 
                                                   $attr->{identity}),
     _debug => $attr->{debug}
  }, $class;
}
sub exec
{
  my ($self, $params) = @_;
  croak q|must pass valid cell and command as attributes!| 
    unless (defined $params->{cell} and defined $params->{command});

  my @output = ();
  for (split /\n/, $params->{command}) {
    my $result = $self->{_HANDLE}->query($params->{cell}, $_);
    print $result, "\n" if $self->{_debug};
    push @output, (split /\n/, $result);
  }
  $self->{_cellAlive}    = (grep /No Route to cell for packet/, @output) ? 0 : 1;
  $self->{_timedOut}     = (grep /Request timed out/, @output) ? 1 : 0;
  $self->{_hasException} = (grep /Exception/, @output) ? 1 : 0;

  @output;
}
sub cell_alive
{
  my $self = shift;
  $self->{_cellAlive};
}
sub hasException
{
  my $self = shift;
  $self->{_hasException};
}
sub timedOut
{
  my $self = shift;
  $self->{_timedOut};
}
sub logoff
{
  my $self = shift;
  $self->{_HANDLE}->logoff;
}
sub DESTROY
{
  my $self = shift;
}

1;
__DATA__
__Java__
import java.io.File;
import java.io.FileNotFoundException;
import java.util.HashMap;

import org.pcells.services.connection.DomainConnection;
import org.pcells.services.connection.DomainConnectionListener;
import org.pcells.services.connection.DomainEventListener;
import org.pcells.services.connection.Ssh1DomainConnection;
import dmg.cells.nucleus.NoRouteToCellException;

public class JAdmin implements Runnable {
  private static boolean DEBUG = false;
  private Ssh1DomainConnection conn;
  private MyDomainEventListener listener;
  private QueryStore store = new QueryStore();
  public JAdmin(final String host, 
                int port, 
                final String user, 
                final String identity) throws Exception 
  {
    conn = new Ssh1DomainConnection(host, port) ;
    conn.setLoginName(user);

    // use one of the two
    if (identity.startsWith("/")) {
      conn.setPassword("");
      try {
        conn.setIdentityFile(new File(identity));
      }
      catch (FileNotFoundException ex) {
        ex.printStackTrace();
        System.exit(1); 
      }
    }
    else 
      conn.setPassword(identity);

    // now the event handler
    listener = new MyDomainEventListener(store);
    conn.addDomainEventListener(listener);

    (new Thread(this)).start();
  }
  public void run() {
    try {
      conn.go();
    }
    catch (Exception ex) {
      ex.printStackTrace();
    }
  }
  public String query(final String cell, final String cmd) throws Exception {
    while (!listener.isReady()) {
      Thread.sleep(1); // ms
    }
    int queryId = listener._sendObject(cell, cmd);
    Integer obj = new Integer(queryId);
    while (!store.isReady(obj)) {
      Thread.sleep(1); // ms
    }
    return store.retrieve(obj).toString();
  }
  public String query(final String cmd) throws Exception {
    while (!listener.isReady()) {
      Thread.sleep(1); // ms
    }
    int queryId = listener._sendObject(cmd);
    Integer obj = new Integer(queryId);
    while (!store.isReady(obj)) {
      Thread.sleep(1); // ms
    }
    return store.retrieve(obj).toString();
  }
  public String logoff() throws Exception {
    return query("logoff");
  }
  protected void finalize() throws Exception {
    System.err.println("logoff");
    logoff(); 
  }
  public static void main(String [] args) throws Exception {
    if (args.length < 2) {
      System.err.println("Usage : <hostname> <portNumber>");
      System.exit(4);
    }
    String hostname = args[0];
    int portnumber = Integer.parseInt(args[1]);
    JAdmin admin = new JAdmin(hostname, portnumber, "admin", "/root/.ssh/identity");
    Object result = admin.query("cmsdcache13_2", "rep ls");
    System.out.println(result);
    result = admin.query("cmsdcache13_2", "info");
    System.out.println(result);
    System.out.println(admin.query("logoff"));
    System.exit(0);
  }
}
class QueryStore {
  private HashMap<Integer, Object> map = new HashMap<Integer, Object>();
  public void save(Integer id, Object obj) {
    map.put(id, obj);
  }
  public Object retrieve(Integer id) {
    return (map.containsKey(id) ? map.get(id) : null);
  }
  public boolean isReady(Integer id) {
    return (map.containsKey(id) ? true : false);
  }
}
class MyDomainEventListener
      implements DomainConnectionListener, DomainEventListener 
{
  private static boolean DEBUG = false;
  private static int connectionId = 0;
  private static int queryId = 0;
  private boolean _active = false;
  QueryStore store;
  private DomainConnection connection;
  public MyDomainEventListener(QueryStore store) {
    this.store = store;   
  } 
  public void connectionOpened(DomainConnection connection) {
    ++connectionId;
    _active = true;
    this.connection = connection;
  }
  public void domainAnswerArrived(Object obj, int id) {
    if (DEBUG) System.out.println("id : " + id + "\nAnswer : " + obj);
    store.save(new Integer(id), obj);
  } 
  public int _sendObject(final String cell, final String cmd) throws Exception {
    ++queryId;
    this.connection.sendObject(cell, cmd, this, queryId);
    return queryId;
  }
  public int _sendObject(final String cmd) throws Exception {
    ++queryId;
    this.connection.sendObject(cmd, this, queryId);
    return queryId;
  }
  public void connectionOutOfBand(DomainConnection connection, Object obj) {
    System.out.println("connection outOfband...");
  }
  public void connectionClosed(DomainConnection connection) {
    System.out.println("connection closed...");
  }
  public boolean isReady() {
    return _active;
  }
}
