use ExtUtils::MakeMaker;

%mods = ( 
  Curses  => 1,
  );

WriteMakefile(
  NAME        => 'Curses::Widgets',
  AUTHOR      => 'Arthur Corliss <corliss@digitalmages.com>',
  ABSTRACT    => 
    'High level access to widgets for rapid interface design.',
  VERSION     => '1.996',
  PREREQ_PM   => \%mods
);


